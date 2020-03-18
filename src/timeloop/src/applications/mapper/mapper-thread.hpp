/* Copyright (c) 2019, NVIDIA CORPORATION. All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of NVIDIA CORPORATION nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "model/engine.hpp"

extern bool gTerminate;

enum class Betterness
{
  Better,
  SlightlyBetter,
  SlightlyWorse,
  Worse
};
  
static double Cost(const model::Topology::Stats& stats, const std::string metric)
{
  if (metric == "delay")
  {
    return static_cast<double>(stats.cycles);
  }
  else if (metric == "energy")
  {
    return stats.energy;
  }
  else if (metric == "last-level-accesses")
  {
    return stats.last_level_accesses;
  }
  else
  {
    assert(metric == "edp");
    return (stats.energy * stats.cycles);
  }
}

static Betterness IsBetterRecursive_(const model::Topology::Stats& candidate, const model::Topology::Stats& incumbent,
                                     const std::vector<std::string>::const_iterator metric,
                                     const std::vector<std::string>::const_iterator end)
{
  const double tolerance = 0.001;

  double candidate_cost = Cost(candidate, *metric);
  double incumbent_cost = Cost(incumbent, *metric);

  double relative_improvement = incumbent_cost == 0 ? 1.0 :
    (incumbent_cost - candidate_cost) / incumbent_cost;

  if (abs(relative_improvement) > tolerance)
  {
    // We have a clear winner.
    if (relative_improvement > 0)
      return Betterness::Better;
    else
      return Betterness::Worse;
  }
  else
  {
    // Within tolerance range, try to recurse.
    if (std::next(metric) == end)
    {
      // Base case. NOTE! Equality is categorized as SlightlyWorse (prefers incumbent).
      if (relative_improvement > 0)
        return Betterness::SlightlyBetter;
      else
        return Betterness::SlightlyWorse;
    }
    else
    {
      // Recursive call.
      Betterness lsm = IsBetterRecursive_(candidate, incumbent, std::next(metric), end);
      if (lsm == Betterness::Better || lsm == Betterness::Worse)
        return lsm;
      // NOTE! Equality is categorized as SlightlyWorse (prefers incumbent).
      else if (relative_improvement > 0)
        return Betterness::SlightlyBetter;
      else
        return Betterness::SlightlyWorse;
    }      
  }
}

static inline bool IsBetter(const model::Topology::Stats& candidate, const model::Topology::Stats& incumbent,
                            const std::vector<std::string>& metrics)
{
  Betterness b = IsBetterRecursive_(candidate, incumbent, metrics.begin(), metrics.end());
  return (b == Betterness::Better || b == Betterness::SlightlyBetter);
}

static inline bool IsBetter(const model::Topology::Stats& candidate, const model::Topology::Stats& incumbent,
                            const std::string& metric)
{
  std::vector<std::string> metrics = { metric };
  return IsBetter(candidate, incumbent, metrics);
}

struct EvaluationResult
{
  bool valid = false;
  Mapping mapping;
  model::Topology::Stats stats;

  bool UpdateIfBetter(const EvaluationResult& other, const std::vector<std::string>& metrics)
  {
    bool updated = false;
    if (other.valid &&
        (!valid || IsBetter(other.stats, stats, metrics)))
    {
      valid = true;
      mapping = other.mapping;
      stats = other.stats;
      updated = true;
    }
    return updated;
  }
};

//--------------------------------------------//
//               Mapper Thread                //
//--------------------------------------------//

class MapperThread
{
 private:
  // Configuration information sent from main thread.
  unsigned thread_id_;
  search::SearchAlgorithm* search_;
  mapspace::MapSpace* mapspace_;
  std::mutex* mutex_;
  uint128_t search_size_;
  std::uint32_t timeout_;
  std::uint32_t victory_condition_;
  uint128_t sync_interval_;
  bool log_stats_;
  bool log_suboptimal_;
  std::ostream& log_stream_;
  bool live_status_;
  bool diagnostics_on_;
  std::vector<std::string> optimization_metrics_;
  model::Engine::Specs arch_specs_;
  problem::Workload &workload_;
  EvaluationResult* best_;
    
  // Thread-local data.
  std::thread thread_;
  EvaluationResult thread_best_;
  std::vector<uint128_t> invalid_eval_counts_;
  std::vector<Mapping> invalid_eval_sample_mappings_;

 public:
  MapperThread(
    unsigned thread_id,
    search::SearchAlgorithm* search,
    mapspace::MapSpace* mapspace,
    std::mutex* mutex,
    uint128_t search_size,
    std::uint32_t timeout,
    std::uint32_t victory_condition,
    uint128_t sync_interval,
    bool log_stats,
    bool log_suboptimal,
    std::ostream& log_stream,
    bool live_status,
    bool diagnostics_on,
    std::vector<std::string> optimization_metrics,
    model::Engine::Specs arch_specs,
    problem::Workload &workload,
    EvaluationResult* best
    ) :
      thread_id_(thread_id),
      search_(search),
      mapspace_(mapspace),
      mutex_(mutex),
      search_size_(search_size),
      timeout_(timeout),
      victory_condition_(victory_condition),
      sync_interval_(sync_interval),
      log_stats_(log_stats),
      log_suboptimal_(log_suboptimal),
      log_stream_(log_stream),
      live_status_(live_status),
      diagnostics_on_(diagnostics_on),
      optimization_metrics_(optimization_metrics),
      arch_specs_(arch_specs),
      workload_(workload),
      best_(best),
      thread_(),
      invalid_eval_counts_(arch_specs_.topology.NumLevels(), 0),
      invalid_eval_sample_mappings_(arch_specs_.topology.NumLevels())
  {
  }

  void Start()
  {
    // We can do this because std::thread is movable.
    thread_ = std::thread(&MapperThread::Run, this);
  }

  void Join()
  {
    thread_.join();
  }

  EvaluationResult& BestResult()
  {
    return thread_best_;
  }

  std::vector<uint128_t>& InvalidEvalCounts()
  {
    return invalid_eval_counts_;
  }

  std::vector<Mapping>& InvalidEvalSampleMappings()
  {
    return invalid_eval_sample_mappings_;
  }

  void Run()
  {
    uint128_t total_mappings = 0;
    uint128_t valid_mappings = 0;
    uint128_t invalid_mappings_mapcnstr = 0;
    uint128_t invalid_mappings_eval = 0;
    std::uint32_t mappings_since_last_best_update = 0;

    const int ncurses_line_offset = 6;
      
    model::Engine engine;
    engine.Spec(arch_specs_);

    // =================
    // Main mapper loop.
    // =================
    while (true)
    {
      if (live_status_)
      {
        std::stringstream msg;

        msg << std::setw(3) << thread_id_ << std::setw(11) << total_mappings
            << std::setw(11) << (total_mappings - valid_mappings)  << std::setw(11) << valid_mappings
            << std::setw(11) << invalid_mappings_mapcnstr + invalid_mappings_eval
            << std::setw(11) << mappings_since_last_best_update;

        if (valid_mappings > 0)
        {
          msg << std::setw(10) << std::fixed << std::setprecision(2) << (thread_best_.stats.utilization * 100) << "%"
              << std::setw(11) << std::fixed << std::setprecision(3) << thread_best_.stats.energy /
            thread_best_.stats.maccs;
        }

        mutex_->lock();
        mvaddstr(thread_id_ + ncurses_line_offset, 0, msg.str().c_str());
        refresh();
        mutex_->unlock();
      }

      // Termination conditions.
      bool terminate = false;

      if (gTerminate)
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "] STATEMENT: "
                    << "global termination flag activated, terminating search."
                    << std::endl;
        mutex_->unlock();
        terminate = true;
      }

      if (search_size_ > 0 && valid_mappings == search_size_)
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "] STATEMENT: " << search_size_
                    << " valid mappings found, terminating search."
                    << std::endl;
        mutex_->unlock();
        terminate = true;
      }

      if (victory_condition_ > 0 && mappings_since_last_best_update == victory_condition_)
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "] STATEMENT: " << victory_condition_
                    << " suboptimal mappings found since the last upgrade, terminating search."
                    << std::endl;
        mutex_->unlock();
        terminate = true;
      }
        
      if ((invalid_mappings_mapcnstr + invalid_mappings_eval) > 0 &&
          (invalid_mappings_mapcnstr + invalid_mappings_eval) == timeout_)
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "] STATEMENT: " << timeout_
                    << " invalid mappings (" << invalid_mappings_mapcnstr << " fanout, "
                    << invalid_mappings_eval << " capacity) found since the last valid mapping, "
                    << "terminating search." << std::endl;
        mutex_->unlock();
        terminate = true;
      }

      // Try to obtain the next mapping from the search algorithm.
      mapspace::ID mapping_id;
      if (!search_->Next(mapping_id))
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "] STATEMENT: "
                    << "search algorithm is done, terminating search."
                    << std::endl;        
        mutex_->unlock();
        terminate = true;
      }

      // Terminate.
      if (terminate)
      {
        if (live_status_)
        {
          mutex_->lock();
          mvaddstr(thread_id_ + ncurses_line_offset, 0, "-");
          refresh();
          mutex_->unlock();
        }
        break;
      }

      //
      // Periodically sync thread_best with global best.
      //
      if (total_mappings != 0 && sync_interval_ > 0 && total_mappings % sync_interval_ == 0)
      {
        mutex_->lock();
          
        // Sync from global best to thread_best.
        bool global_pulled = false;
        if (best_->valid)
        {
          if (thread_best_.UpdateIfBetter(*best_, optimization_metrics_))
          {
            global_pulled = true;
          }
        }

        // Sync from thread_best to global best.
        if (thread_best_.valid && !global_pulled)
        {
          best_->UpdateIfBetter(thread_best_, optimization_metrics_);
        }
          
        mutex_->unlock();
      }

      //
      // Begin Mapping. We do this in several stages with increasing algorithmic
      // complexity and attempt to bail out as quickly as possible at each stage.
      //
      bool success = true;
      std::vector<model::EvalStatus> status_per_level;

      // Stage 1: Construct a mapping from the mapping ID. This step can fail
      //          because the space of *legal* mappings isn't dense (unfortunately),
      //          so a mapping ID may point to an illegal mapping.
      Mapping mapping;

      success &= mapspace_->ConstructMapping(mapping_id, &mapping);
      total_mappings++;

      if (!success)
      {
        invalid_mappings_mapcnstr++;
        search_->Report(search::Status::MappingConstructionFailure);
        continue;
      }

      // Stage 2: (Re)Configure a hardware model to evaluate the mapping
      //          on, and run some lightweight pre-checks that the
      //          model can use to quickly reject a nest.
      //engine.Spec(arch_specs_);
      status_per_level = engine.PreEvaluationCheck(mapping, workload_, !diagnostics_on_);
      success &= std::accumulate(status_per_level.begin(), status_per_level.end(), true,
                                 [](bool cur, const model::EvalStatus& status)
                                 { return cur && status.success; });

      if (!success)
      {
        invalid_mappings_eval++;
        if (diagnostics_on_)
        {
          for (unsigned level = 0; level < arch_specs_.topology.NumLevels(); level++)
          {
            if (!status_per_level.at(level).success)
            {
              // Collect 1 sample failed mapping per level.
              if (invalid_eval_counts_.at(level) == 0)
                invalid_eval_sample_mappings_.at(level) = mapping;
              invalid_eval_counts_.at(level)++;
            }
          }
        }
        search_->Report(search::Status::EvalFailure);
        continue;
      }

      // Stage 3: Heavyweight evaluation.
      status_per_level = engine.Evaluate(mapping, workload_, !diagnostics_on_);
      success &= std::accumulate(status_per_level.begin(), status_per_level.end(), true,
                                 [](bool cur, const model::EvalStatus& status)
                                 { return cur && status.success; });
      if (!success)
      {
        invalid_mappings_eval++;
        if (diagnostics_on_)
        {
          for (unsigned level = 0; level < arch_specs_.topology.NumLevels(); level++)
          {
            if (!status_per_level.at(level).success)
            {
              // Collect 1 sample failed mapping per level.
              if (invalid_eval_counts_.at(level) == 0)
                invalid_eval_sample_mappings_.at(level) = mapping;
              invalid_eval_counts_.at(level)++;
            }
          }
        }
        search_->Report(search::Status::EvalFailure);
        continue;
      }

      // SUCCESS!!!
      auto stats = engine.GetTopology().GetStats();
      EvaluationResult result = { true, mapping, stats };

      valid_mappings++;
      if (log_stats_)
      {
        mutex_->lock();
        log_stream_ << "[" << thread_id_ << "] INVALID " << total_mappings << " " << valid_mappings
                    << " " << invalid_mappings_mapcnstr + invalid_mappings_eval << std::endl;
        mutex_->unlock();
      }        
      invalid_mappings_mapcnstr = 0;
      invalid_mappings_eval = 0;
      search_->Report(search::Status::Success, Cost(stats, optimization_metrics_.at(0)));

      if (log_suboptimal_)
      {
        mutex_->lock();
        log_stream_ << "[" << std::setw(3) << thread_id_ << "]" 
                    << " Utilization = " << std::setw(4) << std::fixed << std::setprecision(2) << stats.utilization 
                    << " | pJ/MACC = " << std::setw(8) << std::fixed << std::setprecision(3) << stats.energy /
          stats.maccs << std::endl;
        mutex_->unlock();
      }

      // Is the new mapping "better" than the previous best mapping?
      if (thread_best_.UpdateIfBetter(result, optimization_metrics_))
      {
        if (log_stats_)
        {
          // FIXME: improvement only captures the primary stat.
          double improvement = thread_best_.valid ?
            (Cost(thread_best_.stats, optimization_metrics_.at(0)) - Cost(stats, optimization_metrics_.at(0))) /
            Cost(thread_best_.stats, optimization_metrics_.at(0)) : 1.0;
          mutex_->lock();
          log_stream_ << "[" << thread_id_ << "] UPDATE " << total_mappings << " " << valid_mappings
                      << " " << mappings_since_last_best_update << " " << improvement << std::endl;
          mutex_->unlock();
        }
        
        if (!log_suboptimal_)
        {
          mutex_->lock();
          log_stream_ << "[" << std::setw(3) << thread_id_ << "]" 
                      << " Utilization = " << std::setw(4) << std::fixed << std::setprecision(2) << stats.utilization 
                      << " | pJ/MACC = " << std::setw(8) << std::fixed << std::setprecision(3) << stats.energy /
            stats.maccs << std::endl;
          mutex_->unlock();
        }

        mappings_since_last_best_update = 0;
      }
      else
      {
        mappings_since_last_best_update++;
      }
    } // while ()
      
    //
    // End Mapping.
    //
  }
};
