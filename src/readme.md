# TreeLLM Project Overview

## Overview

TreeLLM is designed to enhance the accuracy and performance of Large Language Model (LLM) API calls by utilizing large context windows. The project achieves this by:

- Parsing the file from which the prompt was triggered.
- Systematically adding relevant context using the tree structure of a folder to organize the context hierarchically.

## Objectives

The primary goals of TreeLLM are to:

- Reduce repetition of code.
- Enhance understanding of project goals at a high level for each API call.
- Maintain consistent coding style.
- Respect the integrity of previously implemented custom types.

This will be written in Zig with a socket server for reading and parsing filesystem trees from Nvim processes. 
