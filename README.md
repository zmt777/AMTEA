# AMTEA

**Adaptive Multitask Evolutionary Algorithm for Personalized Dynamic Network Biomarker Identification**

This project accompanies the manuscript:

> A Network Entropy Knowledge Transferred Multitask Evolutionary Algorithm for Personalized Dynamic Network Biomarker Identification

## Overview

AMTEA studies personalized dynamic network biomarker identification through cooperation between optimization tasks based on the DNB warning score and network entropy.

Candidate biomarker modules are represented by binary gene selection vectors on personalized gene interaction networks. The framework described in the manuscript balances biological indicators against the number of selected genes.

## Optimization Framework

The manuscript defines two main tasks and four auxiliary tasks:

| Task | Biological optimization target |
| --- | --- |
| FMT | Maximize the DNB warning score |
| FAT1 | Maximize internal abnormality |
| FAT2 | Minimize external coupling |
| NMT | Maximize the sum of node entropy and edge entropy |
| NAT1 | Maximize node entropy |
| NAT2 | Maximize edge entropy |

All tasks also minimize the number of selected genes. The auxiliary tasks provide complementary search directions, while the main tasks retain the complete biological indicators.

The proposed framework combines:

- Sparse initialization guided by gene preferences learned for each task.
- Auxiliary task construction from biological indicator components.
- Selective knowledge transfer based on relative search progress and population similarity.
- Evaluation of transferred candidates under the receiving task's objectives before environmental selection.

## Development Environment

The development code is written in MATLAB. Parts of the supplied development code use:

- Parallel Computing Toolbox.
- Statistics and Machine Learning Toolbox.
- Environmental selection utilities adapted from PlatEMO.

The tested MATLAB release and complete dependency configuration should be specified with the source-code release.

## Reproducing the Experiments

This project is intended to reproduce the experiments reported in the accompanying paper through a unified MATLAB workflow.

Reproduction requires the complete implementation, patient-specific network inputs, and the required MATLAB toolboxes. Detailed execution commands and the validated entry point will be documented with the complete source-code release.

## Data

The manuscript considers TCGA breast invasive carcinoma (BRCA), lung adenocarcinoma (LUAD), and lung squamous cell carcinoma (LUSC) datasets.

The optimization tasks operate on weighted personalized gene interaction networks. Input preparation instructions and gene index mappings should accompany the reproduction workflow.

## Citation

Publication details and citation information for the accompanying manuscript will be added when available.

## Acknowledgements

Some development routines originate from PlatEMO. Original copyright and attribution notices must be retained when using those components.

Platform reference:

Ye Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin. PlatEMO: A MATLAB platform for evolutionary multi-objective optimization [educational forum]. IEEE Computational Intelligence Magazine, 2017, 12(4): 73–87.
