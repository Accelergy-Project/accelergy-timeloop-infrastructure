from setuptools import setup
import os

def readme():
      with open('README.md') as f:
            return f.read()

setup(
      name='accelergy-aladdin-plug-in',
      version='0.1',
      description='An energy estimation plug-in for Accelergy framework',
      classifiers=[
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Topic :: Scientific/Engineering :: Electronic Design Automation (EDA)',
      ],
      keywords='accelerator hardware energy estimation aladdin',
      author='Yannan Wu',
      author_email='nelliewu@mit.edu',
      license='MIT',
      install_requires = ['pyYAML'],
      python_requires = '>=3.6',
      data_files=[
                  ('share/accelergy/estimation_plug_ins/accelergy-aladdin-plug-in',
                    ['aladdin.estimator.yaml',
                     'aladdin_table.py']),
                  ('share/accelergy/estimation_plug_ins/accelergy-aladdin-plug-in/data',
                    ['data/adder.csv',
                     'data/bitwise.csv',
                     'data/fp_dp_adder.csv',
                     'data/fp_dp_multiplier.csv',
                     'data/fp_sp_adder.csv',
                     'data/fp_sp_multiplier.csv',
                     'data/multiplier.csv',
                     'data/reg.csv',
                     'data/shifter.csv',
                     'data/crossbar.csv',
                     'data/counter.csv',
                     'data/comparator.csv']),
                  ],
      include_package_data = True,
      entry_points = {},
      zip_safe = False,
    )
