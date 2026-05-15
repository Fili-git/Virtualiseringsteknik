# Certificate Authority
An internal Certificate Authority (CA) which manages and issues certifications for internal services. While a Webserver using HTTPS, sends Certificate Signing Request (CSR) and recieves a signed certificate (crt).


## Table of Contents
- [Architecture](#Architecture)
- [Environment and IP-addresses](#Environment-and-IP-addresses)
- [Folder structure](#Folder-structure)
- [Components](#Components)
- [Requirements](#Requirements)
- [How to use](#How-to-use)
- [Security Discussion](#Security-Discussion)
- [Design choices and motivation](#Design-choices-and-motivation)


## Architecture
 ![Diagram](https://github.com/Fili-git/Virtualiseringsteknik/blob/main/Virtualiseringsteknik%20Diagram.png)


## Environment and IP-addresses

| VM        | Role           | IP-Address  | Description  |
| ------------- |-------------| -----|-----|
| CA      | Certificate Authority | 10.0.0.1 |Certificate Authority and Ansible node.
| Webserver1     | Webserver      | 10.0.0.2 |Webserver hosted by Nginx.
| Webserver2 | Webserver      | 10.0.0.3 |Webserver hosted by Nginx.

## Folder structure
```
|   .gitignore
|   README.md
|   Virtualiseringsteknik.png
+---ansible
|   |   ansible.cfg
|   |   hosts.ini
|   |   site.yml
|   \---roles
|       +---config
|       |   \---tasks
|       |           main.yml
|       +---csr
|       |   \---tasks
|       |           main.yml
|       +---nginx
|       |   +---handlers
|       |   |       main.yml
|       |   \---tasks
|       |           main.yml
|       \---sign
|           \---tasks
|                   main.yml
\---vagrant
    |   Vagrantfile
    \---.vagrant
```
## Components
Vagrantfile
    
- Defines and creates our VMs, with host names, IP-addreses and resources. Generates key pairs. Installs Ansible and clones Git Repo on the CA/ansible node.

hosts.ini
    
- Points to our ansible-users and their IP-addresses.

site.yml
    
- Automates our signing requests (CSR) and our certification (crt) as well as install and configure Nginx.

ansible.cfg

- Configuration for ```ansible-playbook``` that points to hosts.ini for simpler deployment.

Role - Config
    
- Basic configuration for the CA, including setting up a self signing certificate.

Role - CSR
    
- Creates directory on webserver, generates webserver-key, and a creates certificate signing request (CSR).

Role - Nginx
    
- Install, configure, restart and ensure Nginx is running. Makes sure it is listening to port 443 and displays a static message for user.

Role - Sign
    
- Fetches CSR from webserver, copies CSR to CA and signes the CSR. Sends the certificate back to the webserver(s).


## Requirements
Software requirements for host computer:
- VirtualBox
- Vagrant
- Git

Hardware requirements for host computer:
- 4 GB RAM available.


## How to use

1. Clone repository
   <br>On host: ```Git clone git@github.com:Fili-git/Virtualiseringsteknik.git```
   <br>On host: ```cd /Virtualiseringsteknik```
2. Start all VMs
 <br>On host: ```cd vagrant```
 <br>On host: ```vagrant up```
3. SSH into CA
 <br>On host: ```vagrant ssh ca```
4. Run ansible-playbook
 <br>On CA: ```cd ~/Virtualiseringsteknik/ansible```
 <br>On CA: ```ansible-playbook site.yml```
5. Trust the CA (optional)
   <br>On CA: ```cp /opt/ca/ca.crt /vagrant/ca.crt```
   <br>On host: Install the certificate into Trusted Root Certification Authoritites.
6. Verify configuration
   <br>On host in browser, go to: https://10.0.0.2 or https://10.0.0.3
   <br>**Expected results:**
   <br>If optional step is done, user should be able to access the url and read the message without any security warnings. If not, the browser should claim the connection is insecure but allow connection after explicitly telling it to. The message should display the associated IP address.


## Security Discussion
### (Lack of) Password protection
For the scope of this project, we’ve focused more on the function of the system rather than maximum security with password protected certificates and SSH-keys. This streamlined testing and reduced possible errors during our learning process regarding both Vagrant and Ansible.

In a real environment, password protection is necessary. Having SSH-keys without protection means that a threat actor could connect easily to our different hosts and possibly change configurations, look at secret files or listen to traffic coming through. With web servers in mind, they could theoretically take control over the hosted webpage and display unauthorized messages or simply shut it down.

### Certificate Revocation
In the current configuration, there’s no way to revoke a created certificate. If a threat actor were to compromise a private key, or in another way get the ability to use the certificate in a malicious way, it’s important to be able to revoke the certificate and render it unusable.

One would also like to revoke a certificate if the website is being shut down, the domain is no longer owned by the holder, or the intended service is no longer in use.

We chose to not include a way for certificate revocation in this project due to the scope of the assignment. To implement it in a production setting, one could use either a Certificate Revocation List or an OCSP endpoint.

### Key distribution
Should go through a secrets manager such as HashiCorp Vault instead of the current shared file setup. As it is now, the CA handles the webserver key during the signing process through /tmp/, which means that it briefly exists in two places at the same time. In a real production environment the private keys should never leave their associated machine. Instead only the CSR should be shared between the webserver and the CA.

Using a secrets manager, it can take care of distributing and protecting secret information such as credentials and keys, which reduces the risk of a data leak that compromises the production. It can also log who access secrets and when it happened, which helps in detecting malicious activity as well as following compliance standards.

As it is now, all files placed in /vagrant/ are also synced to the host filesystem, which means that keys placed there are exposed to the host OS. This would be a high risk in a production setting, since access to the host also gives access to information about the keys.

### Single Point Failure - CA VM 
The CA VM acts as both our Certificate Authority and our Ansible controller, which if compromised or fails would break both the PKI and automation simultaneously. In a real or large-scale environment, one should separate these two into independent VMs. 

Our keys also exist on the CA and have SSH access to other VMs. In a real-life setup, the CA would be offline or air-gapped and only come online to receive and sign an incoming CSR. As it is now, a compromised CA key would mean that all certificates and their signing are untrustworthy. As it is now, an attacker with access to the CA could sign certificates to appear legitimate and because it also acts as our Ansible controller, they could possibly cause significant damage to the infrastructure and system.

Currently, Ansible playbook uses many root privileges for its tasks. In a real production, we would limit these to only the tasks that need it, such as installing packages. Running everything from root increases the potential damage if something goes wrong or is compromised.

### Self signed certificate
To ensure a verified, secure connection in the current configuration, the user needs to manually install the Root certificate generated by the CA VM. This certificate is self-signed by the CA without further verification of legitimacy. In a production setting, one would prefer to use a certificate authorized by a trusted service, or use an AD group policy. 

Installing a root certificate on a host establishes a chain of trust through the continued system. Installing a certificate of an unknown origin could lead to a compromised chain of trust, either due to misconfiguration or by design from a threat actor.

If a company would choose to do this kind of setup by manually installing certificates on each and every relevant host, they also need to make sure that all certificates are up to date and correct which is time consuming and increases the risk for mistakes.

### Final thoughts on security
This project has not been designed with security as a priority, instead we chose to focus on learning how to use Ansible and Ruby, get familiar with automation and to create a working certificate chain. This means that certain security risks and hardening techniques were intentionally omitted to focus on the specific project at hand.

Since we also learned about Git by applying the principle of “learning by doing”, we have probably made a number of security related rookie mistakes by committing things that shouldn’t have been, or missed adding something to .gitignore. 

If we were to do a similar project in a production setting, we would start with adding password protection and a way to revoke certificates. These are two somewhat simpler additions that would increase the security by a lot, to reach a level that would be much more appropriate for a non-educational situation. Even though these might not be the most critical things, we reason that they are easily fixed to gain some kind of security.

After that, we’d look at our key distribution, to remove the transfer of keys that happens right now. By implementing a secrets manager, the public transfer would no longer happen and the keys would no longer be accessible easily from the host’s filesystem. Changing the current system to something securer is highly prioritized and should definitely be done before running this kind of project in a production setting.

To split the now multi-purpose CA VM into two machines with their own purpose, would help protect the chain of trust by making it harder to change the configuration of the Certificate Authority by either a mistake or ill intent. Having a separate Ansible Node also makes it easier to change parts of the Ansible Playbook without risking the integrity of the CA.

Last, but not least, we would look over the self signed certificate and instead implement public, trusted CA. This removes the need to install the created root CA on each webserver. It also outsources any potential security threats related to specifically the root CA, to an external source which mitigates the production company’s risk.

## Design choices and motivation
### Development
When we first began this project, our knowledge with both Ansible and Vagrant was quite limited, which is also noticeable in our early commits. For example, all Ansible tasks were in the same file so we could test the tasks without having to figure out our complete role structure. After learning more and realising that splitting up the tasks enhanced our scalability as well as followed industry standard, we decided to implement that structure instead.

During the entire process, we focused first on making things work and second on making it look good behind the scenes. Since both of us were new to this kind of programming and automation, we didn’t want to get stuck on small details and miss the larger picture. As we became more confident and learnt more, we trimmed away excess and polished our structure. Looking back to our earliest commits, we can see great improvement in our work.

### Scope
We have chosen to keep it simple and contained for educational purposes, and lessen the risk of making it too large and out of scope. We wanted to focus our time on understanding and learning more about the modules we have implemented. We chose to use Nginx over Python due to our own lack of experience with programming. Nginx was thus more beginner friendly for us to use in this project since we didn’t need to also learn a third new programming language in addition to Ruby and Ansible.

### IP Addresses
The IP addresses are chosen for readability, rather than functionality. We decided to use 10.0.0.x in order to have a clear overview, make errors more visible to detect and testing easier. In a proper production, it would be more appropriate to use other IP addresses since the 10.x.x.x is internal.

### Virtual Machines
We decided to reduce the amount of Virtual Machines, by combining the Ansible node with our Certificate Authority. We found it unnecessary to have a single VM running Ansible and taking up resources. On a larger scale it can be beneficial and more secure to keep them separate for optimization reasons as well as the security reasons, we touched more on this in our security discussion. This requires small changes to the site.yml, ```hosts: localhost``` needs to be changed to ```hosts: CA``` instead.

The RAM assigned to each VM has been chosen from an efficiency point of view, even though they might seem unnecessarily large. We prioritized time over resources to reduce the amount of time we had to wait for downloads and configurations to happen, as we had available computers with the capacity to host and run the machines and needed to test our projects multiple times during limited hours. For a larger production, we highly recommend looking over the assigned RAM and maybe decrease it, based on that project's scope, requirements and resources.

### Scalability
In the current configuration, Vagrant creates two web servers. Due to declaring a list instead of specific hosts it's easy to add more web servers and let Vagrant create more virtual machines with the same baseline configuration.

The Ansible Playbook calls for different tasks, which are written to repeat an appropriate amount based on how many web servers are listed. If one adds more virtual machines to the Vagrant code, the same machines need to be manually added to the Hosts.ini file to include them in the playbook.

---
Created by: Anna Wuolo & Sayla Persson <br>
Course: Virtualiseringsteknik <br>
School: Yrkeshögskolan Enköping <br>
Date: 2026-05-22
