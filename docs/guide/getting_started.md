# Getting started with lea.online

Welcome to the lea.online developer documentation! This guide will help you get started with developing applications and services using the lea.online platform.

## Prerequisites

This guide and the overall development are optimized for Linux-based operating systems.
While it is possible to develop on Windows or macOS, using Linux will provide the best experience and compatibility.

Best experience is reported on Debian based distributions (Debian, Ubuntu, Linux Mint, and others).
We recommend using the latest Long Term Support (LTS) version of Ubuntu for development.

### Node.js and Meteor

Make sure you have Node.js and Meteor installed on your system.
Note that Meteor comes bundled with a specific version of Node.Js so you don't need to install Node.js separately for Meteor projects.

To install Meteor, run the following command in your terminal:

```bash
curl https://install.meteor.com/ | sh
```

For more information on installing Meteor, visit the [official Meteor installation guide](https://www.meteor.com/install).

### Git

Ensure that Git is installed on your system to clone repositories and manage version control.

To install Git on Debian-based systems, use the following command:

```bash
sudo apt install git
```

## Cloning the Repositories

lea.online consists of multiple applications and services.
For a minimal development setup you will need the following repos:

- lea. Accounts (Authentication server)
- lea. Backend (Editing data and configuration)
- lea. Content (Storing and serving data and media files)

and the respective application you want to develop for, e.g.,

- otu.lea (Diagnostic app)
- lea. Dashboard (Teacher analytics)
- lea. App (Mobile learning app)

```bash

```