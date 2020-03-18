# -*- coding: utf-8 -*-
ALADDIN_ACCURACY = 70  # in your metric, please set the accuracy you think Aladdin's estimations are
# MIT License
#
# Copyright (c) 2019 Yannan (Nellie) Wu
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import csv, os, sys, math
from copy import deepcopy
from accelergy.helper_functions import oneD_linear_interpolation, oneD_quadratic_interpolation

class AladdinTable(object):
    """
    A dummy estimation plug-in
    Note that this plug-in is just a placeholder to illustrate the estimation plug-in interface
    It can be used as a template for creating user-defined plug-ins
    The energy values returned by this plug-in is not meaningful
    """
    # -------------------------------------------------------------------------------------
    # Interface functions, function name, input arguments, and output have to adhere
    # -------------------------------------------------------------------------------------
    def __init__(self):
        self.estimator_name =  "Aladdin_table"

        # example primitive classes supported by this estimator
        self.supported_pc = ['regfile', 'counter', 'comparator', 'crossbar', 'wire', 'FIFO',
                             'bitwise', 'intadder', 'intmultiplier', 'intmac',
                             'fpadder', 'fpmultiplier', 'fpmac']
        self.aladdin_area_quries = AladdinAreaQueires(self.supported_pc)

    def primitive_action_supported(self, interface):
        """
        :param interface:
        - contains four keys:
        1. class_name : string
        2. attributes: dictionary of name: value
        3. action_name: string
        4. arguments: dictionary of name: value

        :type interface: dict

        :return return the accuracy if supported, return 0 if not
        :rtype: int

        """
        if 'technology' not in interface['attributes']:
            print('ALADDIN WARN: no technology specified in the request, cannot perform estimation')
        class_name = interface['class_name']
        technology = interface['attributes']['technology']
        if (technology == 40  or technology == '40' or technology == '40nm' or
            technology == 45  or technology == '45' or technology == '45nm') \
                and class_name in self.supported_pc:
            return ALADDIN_ACCURACY
        return 0  # if not supported, accuracy is 0


    def estimate_energy(self, interface):
        """
        :param interface:
        - contains four keys:
        1. class_name : string
        2. attributes: dictionary of name: value
        3. action_name: string
        4. arguments: dictionary of name: value

       :return the estimated energy
       :rtype float

        """
        class_name = interface['class_name']
        query_function_name = class_name + '_estimate_energy'
        energy = getattr(self, query_function_name)(interface)
        return energy

    def primitive_area_supported(self, interface):
        """
        :param interface:
        - contains two keys:
        1. class_name : string
        2. attributes: dictionary of name: value

        :type interface: dict

        :return return the accuracy if supported, return 0 if not
        :rtype: int

        """
        if 'technology' not in interface['attributes']:
            print('ALADDIN WARN: no technology specified in the request, cannot perform estimation')
        class_name = interface['class_name']
        technology = interface['attributes']['technology']
        if (technology == 40  or technology == '40' or technology == '40nm' or
            technology == 45  or technology == '45' or technology == '45nm') \
                and class_name in self.supported_pc and not class_name == 'wire':
            return ALADDIN_ACCURACY
        return 0  # if not supported, accuracy is 0

    def estimate_area(self, interface):
        """
        :param interface:
        - contains two keys:
        1. class_name : string
        2. attributes: dictionary of name: value

        :type interface: dict

        :return the estimated area
        :rtype: float

        """
        area = self.aladdin_area_quries.estimate_area(interface)
        return area

    # ============================================================
    # User's functions, purely user-defined
    # ============================================================
    @staticmethod
    def query_csv_using_latency(interface, csv_file_path):
        # default latency for Aladdin estimation is 5ns
        latency = interface['attributes']['latency'] if 'latency' in interface['attributes'] else 5
        # round to an existing latency (can perform linear interpolation as well)
        if type(latency) is str and 'ns' in latency:
            latency = math.ceil(float(latency.split('ns')[0]))
        elif type(latency) is str and 'ps' in latency:
            latency = math.ceil(float(latency.split('ps')[0])/1000)
        else:
            latency = math.ceil(latency)
        if latency > 10:
            latency = 10
        elif latency > 6:
            latency = 6
        # there are only two types of energy in Aladdin tables
        action_name = 'idle energy(pJ)' if interface['action_name'] == 'idle' else 'dynamic energy(pJ)'
        with open(csv_file_path) as csv_file:
            reader = csv.DictReader(csv_file)
            for row in reader:
                if row['latency(ns)'] == str(latency):
                    energy = float(row[action_name])
                    break
        return energy

    def regfile_estimate_energy(self, interface):
        width = interface['attributes']['width']
        depth = interface['attributes']['depth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/reg.csv')
        if depth == 0:
            return 0
        action_name = interface['action_name']

        if action_name == 'idle':
            reg_interface = deepcopy(interface)
            reg_energy = AladdinTable.query_csv_using_latency(reg_interface, csv_file_path)
            comparator_interface = {'attributes': {'datawidth': math.ceil(math.log2(float(depth)))},
                                    'action_name': 'idle'}
            comparator_energy = self.comparator_estimate_energy(comparator_interface)
        else:
            data_delta = interface['arguments']['data_delta']
            address_delta = interface['arguments']['address_delta']
            reg_interface = deepcopy(interface)
            if data_delta == 0:
                reg_interface['action_name'] = 'idle'
            reg_energy = AladdinTable.query_csv_using_latency(reg_interface, csv_file_path)
            if address_delta == 0:
                comp_action = 'idle'
            else:
                comp_action = action_name
            comparator_interface = {'attributes': {'datawidth': math.ceil(math.log2(float(depth)))},
                                        'action_name': comp_action}
            comparator_energy = self.comparator_estimate_energy(comparator_interface)
        # register file access is naively modeled as vector access of registers
        reg_file_energy = reg_energy * width + comparator_energy * depth
        return reg_file_energy

    def FIFO_estimate_energy(self, interface):
        datawidth = interface['attributes']['datawidth']
        depth = interface['attributes']['depth']
        if depth == 0:
            return 0
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/reg.csv')
        reg_energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)

        if interface['action_name'] == 'idle':
            action_name = 'idle'
        else:
            action_name = 'access'

        comparator_interface = {'attributes': {'datawidth': math.log2(float(depth))},
                                'action_name': action_name}
        comparator_energy = self.comparator_estimate_energy(comparator_interface)
        energy = reg_energy * datawidth + comparator_energy
        return energy


    def crossbar_estimate_energy(self, interface):
        n_inputs = interface['attributes']['n_inputs']
        n_outputs = interface['attributes']['n_outputs']
        datawidth = interface['attributes']['datawidth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/crossbar.csv')
        csv_energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        crossbar_energy = csv_energy * n_inputs * (n_outputs/4) * (datawidth/32)
        return crossbar_energy

    def counter_estimate_energy(self, interface):
        width = interface['attributes']['width']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/counter.csv')
        csv_energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        energy = csv_energy * (width/32)
        return energy

    def wire_estimate_energy(self, interface):
        action_name = interface['action_name']
        if action_name == 'transfer':
            len_str = interface['attributes']['length']
            if 'm' not in len_str:
                length = float(len_str)
            else:
                if 'mm' in len_str:
                    length = float(len_str.split['mm'])*10**-3
                elif 'um' in len_str:
                    length = float(len_str.split['mm']) * 10 ** -6
                elif 'nm' in len_str:
                    length = float(len_str.split['mm']) * 10 ** -9
                else:
                    print('ALADDIN WARN: not recognizing the unit of the wire length, 0 energy')
                    length = 0

            datawidth = interface['attributes']['datawidth']
            C = 1.627 * 10**-15
            VDD = 1
            alpha = 0.2
            E = datawidth * alpha * C * length * VDD ** 2 * 10**12
            return E
        else:
            return 0

    def comparator_estimate_energy(self, interface):
        datawidth = interface['attributes']['datawidth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/comparator.csv')
        csv_energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        energy = csv_energy * (datawidth/32)
        return energy

    def intmac_estimate_energy(self, interface):
        # mac is naively modeled as adder and multiplier
        multiplier_interface = deepcopy(interface)
        if interface['action_name'] == 'mac_gated':
            multiplier_interface['action_name'] = 'mult_gated'
        elif interface['action_name'] == 'mac_reused':
            multiplier_interface['action_name'] = 'mult_reused'
        elif interface['action_name'] == 'idle':
            multiplier_interface['action_name'] = 'idle'
        else:
            multiplier_interface['action_name'] = 'mult_random'
        adder_energy = self.intadder_estimate_energy(interface)
        multiplier_energy = self.intmultiplier_estimate_energy(multiplier_interface)
        energy = adder_energy + multiplier_energy
        return energy

    def fpmac_estimate_energy(self, interface):
        # fpmac is naively modeled as fpadder and fpmultiplier
        multiplier_interface = deepcopy(interface)
        if interface['action_name'] == 'mac_gated':
            multiplier_interface['action_name'] = 'mult_gated'
        elif interface['action_name'] == 'mac_reused':
            multiplier_interface['action_name'] = 'mult_reused'
        elif interface['action_name'] == 'idle':
            multiplier_interface['action_name'] = 'idle'
        else:
            multiplier_interface['action_name'] = 'mult_random'
        fpadder_energy = self.fpadder_estimate_energy(interface)
        fpmultiplier_energy = self.fpmultiplier_estimate_energy(interface)
        energy = fpadder_energy + fpmultiplier_energy
        return energy

    def intadder_estimate_energy(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit = interface['attributes']['datawidth']
        csv_nbit = 32
        csv_file_path = os.path.join(this_dir, 'data/adder.csv')
        energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            energy = oneD_linear_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': energy}])
        return energy

    def fpadder_estimate_energy(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit_exponent = interface['attributes']['exponent']
        nbit_mantissa = interface['attributes']['mantissa']
        nbit = nbit_mantissa + nbit_exponent
        if nbit_exponent + nbit_mantissa <= 32:
            csv_nbit = 32
            csv_file_path = os.path.join(this_dir, 'data/fp_sp_adder.csv')
        else:
            csv_nbit = 64
            csv_file_path = os.path.join(this_dir, 'data/fp_dp_adder.csv')
        energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            energy = oneD_linear_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': energy}])
        return energy

    def intmultiplier_estimate_energy(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit = interface['attributes']['datawidth']
        action_name = interface['action_name']
        if action_name == 'mult_gated':
            interface['action_name'] = 'idle'  # reflect gated multiplier energy
        csv_nbit = 32
        csv_file_path = os.path.join(this_dir, 'data/multiplier.csv')
        energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)

        if not nbit == csv_nbit:
            energy = oneD_quadratic_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': energy}])
        if action_name == 'mult_reused':
            energy = 0.85 * energy
        return energy

    def fpmultiplier_estimate_energy(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        action_name = interface['action_name']
        if action_name == 'mult_gated':
            interface['action_name'] = 'idle'  # reflect gated multiplier energy
        nbit_exponent = interface['attributes']['exponent']
        nbit_mantissa = interface['attributes']['mantissa']
        nbit = nbit_mantissa + nbit_exponent
        if nbit_exponent + nbit_mantissa <= 32:
            csv_nbit = 32
            csv_file_path = os.path.join(this_dir, 'data/fp_sp_multiplier.csv')
        else:
            csv_nbit = 64
            csv_file_path = os.path.join(this_dir, 'data/fp_dp_multiplier.csv')
        energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            energy = oneD_quadratic_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': energy}])
        if action_name == 'mult_reused':
            energy = 0.85 * energy
        return energy

    def bitwise_estimate_energy(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/bitwise.csv')
        csv_energy = AladdinTable.query_csv_using_latency(interface, csv_file_path)
        return csv_energy


#--------------------------------------------------------------------------
# ART-related functions
#---------------------------------------------------------------------------
class AladdinAreaQueires():
    def __init__(self, supported_pc):
        # example primitive classes supported by this estimator
        self.supported_pc = supported_pc

    def estimate_area(self, interface):
        class_name = interface['class_name']
        query_function_name = class_name + '_estimate_area'
        area = getattr(self, query_function_name)(interface)
        return area

    @staticmethod
    def query_csv_area_using_latency(interface, csv_file_path):
        # default latency for Aladdin estimation is 5ns
        if 'latency' in interface['attributes']:
            latency = interface['attributes']['latency']
        else:
            latency = 5
        # round to an exist
        # ing latency (can perform linear interpolation as well)
        if type(latency) is str and 'ns' in latency:
            latency = math.ceil(float(latency.split('ns')[0]))
        else:
            latency = math.ceil(latency)
        if latency > 10:
            latency = 10
        elif latency > 6:
            latency = 6
        # there are only two types of energy in Aladdin tables
        with open(csv_file_path) as csv_file:
            reader = csv.DictReader(csv_file)
            for row in reader:
                if row['latency(ns)'] == str(latency):
                    area = float(row['area(um^2)'])
                    break
        return area

    def regfile_estimate_area(self, interface):
        # register file access is naively modeled as vector access of registers
        # register energy consumption is generated according to latency

        width = interface['attributes']['width']
        depth = interface['attributes']['depth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/reg.csv')
        if depth == 0:
            return 0
        reg_interface = deepcopy(interface)
        reg_area = AladdinAreaQueires.query_csv_area_using_latency(reg_interface, csv_file_path)
        comparator_interface = {'attributes': {'datawidth': math.ceil(math.log2(float(depth)))}}
        comparator_area = self.comparator_estimate_area(comparator_interface)
        # register file access is naively modeled as vector access of registers
        reg_file_area = reg_area * width + comparator_area * depth
        return reg_file_area

    def FIFO_estimate_area(self, interface):
        datawidth = interface['attributes']['datawidth']
        depth = interface['attributes']['depth']
        if depth == 0:
            return 0
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/reg.csv')
        reg_area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        comparator_interface = {'attributes': {'datawidth': math.log2(float(depth))}}
        comparator_area = self.comparator_estimate_area(comparator_interface)
        area = reg_area * datawidth + comparator_area
        return area


    def crossbar_estimate_area(self, interface):
        n_inputs = interface['attributes']['n_inputs']
        n_outputs = interface['attributes']['n_outputs']
        datawidth = interface['attributes']['datawidth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/crossbar.csv')
        csv_area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        crossbar_area = csv_area * n_inputs * (n_outputs/4) * (datawidth/32)
        return crossbar_area

    def counter_estimate_area(self, interface):
        width = interface['attributes']['width']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/counter.csv')
        csv_energy = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        energy = csv_energy * (width/32)
        return energy

    def comparator_estimate_area(self, interface):
        datawidth = interface['attributes']['datawidth']
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/comparator.csv')
        csv_area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        area = csv_area * (datawidth / 32)
        return area

    def intmac_estimate_area(self, interface):
        # mac is naively modeled as adder and multiplier
        adder_area = self.intadder_estimate_area(interface)
        multiplier_area = self.intmultiplier_estimate_area(interface)
        area = adder_area + multiplier_area
        return area

    def fpmac_estimate_area(self, interface):
        # fpmac is naively modeled as fpadder and fpmultiplier
        fpadder_area = self.fpadder_estimate_area(interface)
        fpmultiplier_area = self.fpmultiplier_estimate_area(interface)
        area = fpadder_area + fpmultiplier_area
        return area

    def intadder_estimate_area(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit = interface['attributes']['datawidth']
        csv_nbit = 32
        csv_file_path = os.path.join(this_dir, 'data/adder.csv')
        area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            area = oneD_linear_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': area}])
        return area

    def fpadder_estimate_area(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit_exponent = interface['attributes']['exponent']
        nbit_mantissa = interface['attributes']['mantissa']
        nbit = nbit_mantissa + nbit_exponent
        if nbit_exponent + nbit_mantissa <= 32:
            csv_nbit = 32
            csv_file_path = os.path.join(this_dir, 'data/fp_sp_adder.csv')
        else:
            csv_nbit = 64
            csv_file_path = os.path.join(this_dir, 'data/fp_dp_adder.csv')
        area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            area = oneD_linear_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': area}])
        return area

    def intmultiplier_estimate_area(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit = interface['attributes']['datawidth']
        csv_nbit = 32
        csv_file_path = os.path.join(this_dir, 'data/multiplier.csv')
        area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            area = oneD_quadratic_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': area}])
        return area

    def fpmultiplier_estimate_area(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        nbit_exponent = interface['attributes']['exponent']
        nbit_mantissa = interface['attributes']['mantissa']
        nbit = nbit_mantissa + nbit_exponent
        if nbit_exponent + nbit_mantissa <= 32:
            csv_nbit = 32
            csv_file_path = os.path.join(this_dir, 'data/fp_sp_multiplier.csv')
        else:
            csv_nbit = 64
            csv_file_path = os.path.join(this_dir, 'data/fp_dp_multiplier.csv')
        area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        if not nbit == csv_nbit:
            area = oneD_quadratic_interpolation(nbit, [{'x': 0, 'y': 0}, {'x': csv_nbit, 'y': area}])
        return area

    def bitwise_estimate_area(self, interface):
        this_dir, this_filename = os.path.split(__file__)
        csv_file_path = os.path.join(this_dir, 'data/bitwise.csv')
        csv_area = AladdinAreaQueires.query_csv_area_using_latency(interface, csv_file_path)
        return csv_area

# # helper function (if your accelergy version is < 0.2 use this function directly instead of import)
# def oneD_quadratic_interpolation(desired_x, known):
#     """
#     utility function that performs 1D linear interpolation with a known energy value
#     :param desired_x: integer value of the desired attribute/argument
#     :param known: list of dictionary [{x: <value>, y: <energy>}]
#
#     :return energy value with desired attribute/argument
#
#     """
#     # assume E = ax^2 + c where x is a hardware attribute
#     ordered_list = []
#     if known[1]['x'] < known[0]['x']:
#         ordered_list.append(known[1])
#         ordered_list.append(known[0])
#     else:
#         ordered_list = known
#
#     slope = (known[1]['y'] - known[0]['y']) / (known[1]['x']**2 - known[0]['x']**2)
#     desired_energy = slope * (desired_x**2 - ordered_list[0]['x']**2) + ordered_list[0]['y']
#     return desired_energy
