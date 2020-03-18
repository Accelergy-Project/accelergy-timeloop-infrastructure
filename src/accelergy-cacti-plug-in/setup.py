from setuptools import setup
import os

def readme():
      with open('README.md') as f:
            return f.read()

setup(
      name='accelergy-cacti-plug-in',
      version='0.1',
      description='An energy estimation plug-in for Accelergy framework using CACTI',
      classifiers=[
        'Development Status :: 3 - Alpha',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 3',
        'Topic :: Scientific/Engineering :: Electronic Design Automation (EDA)',
      ],
      keywords='accelerator hardware energy estimation CACTI',
      author='Yannan Wu',
      author_email='nelliewu@mit.edu',
      license='MIT',
      install_requires = ['pyYAML'],
      python_requires = '>=3.6',
      data_files=[
                  ('share/accelergy/estimation_plug_ins/accelergy-cacti-plug-in',
                    ['cacti.estimator.yaml',
                     'cacti_wrapper.py',
                     'default_SRAM.cfg'])
                  ],
      include_package_data = True,
      entry_points = {},
      zip_safe = False,
    )
