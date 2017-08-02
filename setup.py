from codecs import open
from os import path

from setuptools import setup, find_packages

here = path.abspath(path.dirname(__file__))

with open(path.join(here, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

setup(
    name='elmboard',
    version='0.1',
    description='Dashboard using ELM',
    long_description=long_description,
    license='BSD3',
    packages=find_packages(),
    install_requires=[
        'aiohttp == 2.2.3',
        'cchardet == 2.1.1',
    ],
    extras_require={
        'dev': [
            'coverage == 4.4.1',
            'pylint == 1.7.2',
        ],
        'test': [
            'coverage == 4.4.1',
            'pytest == 3.1.3',
            'pytest-cov == 2.5.1',
        ],
    }
)
