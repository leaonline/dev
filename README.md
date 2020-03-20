![lea.online logo, cc-? University of Bremen](https://blogs.uni-bremen.de/leaonline/files/2019/03/cropped-header-lea-online-01-3.png)


This is the main repository for documentation and development.

[Build badge]


You will find the following resources in this repository:

* Introduction to lea.online
* Applications and services overview
* Developer documentation

## Introduction to lea.online

All about lea.online, why, how, who etc.

## Applications and services overview

Describe the arch in most high level view for a broad audience

## Developer documentation

### Architecture

Describe the arch from a more technical viewpoint

![lea.online technical architecture](./architecture/level-0-system-overview.svg)


### Getting started

Explain how to start now, fast, easy

### Submodules structure

This project does not include any of the `leaonline-*` applications or libraries directly but points to specific commits
of these repositories using submodules.

This has several reasons:

* There is a single entry point for newcomers
* There is one main development repository, which installs all related projects in one step
* The main repo can point to certain states, where the whole application and service system is considered stable.
  Think of it like a "snapshot" of the system beyond the state of each individual repositories.
* Contributions can occur on the submodule directories without affecting the "stable" state this repo points to
* Clear release management across multiple repositories


If you need help or want to know how to use submodules, please check out the following resources:

https://git-scm.com/book/en/v2/Git-Tools-Submodules

https://git-scm.com/docs/git-submodule

## Contribution guide

Describe how our contribution workflow looks like

## License

This repository and it's resources are [MIT licensed](./LICENSE). However, the submodules contain their own licenses and they may 
differ from the license of this one.

## Funding

This work is part of the research project "lea.online" (FKN: ????????), funded by the German Federal Ministry of 
Education and Research (BMBF)

Read more about them at the following websites:

- Blog (German language) - https://blogs.uni-bremen.de/leaonline 
- University of Bremen - https://www.uni-bremen.de/en.html
- BMBF - https://www.bmbf.de/en/index.html
