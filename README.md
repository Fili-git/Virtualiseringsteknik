# Certificate Authority
An internal Certificate Authority (CA) which manages and issues certifications for internal services. While a Webserver using HTTPS, sends Certificate Signing Request (CSR) and recieves a signed certificate (crt).


# Table of Contents
- [Architecture](#Architecture)
- [Environment and IP-addresses](#Environment-and-IP-addresses)
- [Folder structure](#Folder-structure)
- [Components](#Components)
- [Requirements](#Requirements)
- [Getting started](#Getting-started)
- [Security Measures](#Security-Measures)
- [Security Analysis](#Security-Analysis)
- [Verification](#Verification)
- [Design choices and motivation](#Design-choices-and-motivation)


# Architecture
    Diagram


# Environment and IP-addresses
## VM 
- Role 
- IP-address 
- Port forwarding 
- Description

## Nginx 
- Endpoint webserver
- IP-address 
- Port forwarding 
- Listens to port 443, uses HTTPS and acts as a basic webserver and endpoint, displaying a message on successful certification.
    
## CA 
- Certificate Authority 
- IP-address 
- Port forwarding 
- Self-signing authority which recieves signing requests (CSR) and return signed certification (crt).

## Webserver 
- Host and Webserver 
- IP-address : 10.0.0.2 
- Port forwarding 
- Runs Nginx, sends CSRs and recieves signed certificates. Responds to port 443 requests with static message.


# Folder structure
    +---ansible
    |   \---roles
    |       +---config
    |       |   \---tasks
    |       +---csr
    |       |   \---tasks
    |       +---nginx
    |       |   +---handlers
    |       |   \---tasks
    |       \---sign
    |           \---tasks
    \---vagrant
        \---.vagrant
            +---machines
            |   +---ca
            |   |   \---virtualbox
            |   \---webserver
            |       \---virtualbox
            \---rgloader


# Components
    Vagrantfile
        Defines and creates our VMs, with host names, IP-addreses and resources. Generates key pairs. Installs Ansible and exposes port 443 for our webserver.
    hosts.ini
        Points to our ansible-users and their IP-addresses.
    site.yml
        Automates our signing requests (CSR) and our certification (crt) as well as install and configure Nginx.
    Role - Config
        Configure certification.
    Role - CSR
        Creates directory on webserver, generates webserver-key, creates certificate signing request (CSR) for new certificate and write CSR to file.
    Role - Nginx
        Install, configure, restart and ensure Nginx is running. Makes sure it is listening to port 443 and displays a message for user.
    Role - Sign
        Fetches CSR from webserver, copies CSR to CA. Checks for exsisting certificates and reads any that do. Signs CSR with our CA, and then writes certificate (crt) and sends back to webserver.


# Requirements
    Software requirements for host computer:
        VirtualBox
        Vagrant
        Git
    Hardware requirements for host computer:
        X GB RAM


# Getting started - Set up/How to
1. Clone repository
   ```Git clone git@github.com:Fili-git/Virtualiseringsteknik.git
   cd /Virtualiseringsteknik
2. Start all VMs
   cd vagrant
   vagrant up
3. SSH into CA
   vagrant ssh ca
4. Run ansible-playbook
   ```Git clone https://github.com/Fili-git/Virtualiseringsteknik.git
   cd ~/Virtualiseringsteknik
   ansible-playbook -i ansible/hosts.ini ansible/site.yml
5. Verification script?
   ex. bash test/verify.sh
6. Trust the CA
   Run ```cp /opt/ca/ca.crt /vagrant/ca.crt``` on CA VM. 
   On host install the certificate into Trusted Root Certification Authoritites.
7. Go onto the webserver
   https://10.0.0.2

Expected results:
   User should be able to access the url and read the message without any security warnings. If step 6 haven't been done, the browser should claim the connection is insecure.


# Security Measures


# Security Analysis


# Verification


# Design choices and motivation
