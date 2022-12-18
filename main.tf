provider "google" {
  credentials = file("mygcp-creds.json")
  project      = "pg-devops1988-10"
  region       = "us-central1"
}
  resource "google_compute_instance" "postgre1" {
  name         = "pg-node1"
  machine_type = "e2-small"
  zone         = "us-central1-a"


  boot_disk {
     initialize_params {
       image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
      
   }


network_interface {
   network = "default"
   access_config {}
}

metadata = {
    ssh-keys = "devops:${file("~/.ssh/id_rsa.pub")}"
    }

connection {
  type = "ssh"
  user = "devops"
  host = "${google_compute_instance.postgre1.network_interface.0.access_config.0.nat_ip}"
  agent = false
  private_key = "${file("~/.ssh/id_rsa")}"
        
 }

provisioner "remote-exec" {
    script = "pg_install.sh"
    }
 }

 resource "google_compute_instance" "postgre2" {
  name         = "pg-node2"
  machine_type = "e2-small"
  zone         = "us-central1-a"


  boot_disk {
     initialize_params {
       image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
      
   }


network_interface {
   network = "default"
   access_config {}
}

metadata = {
    ssh-keys = "devops:${file("~/.ssh/id_rsa.pub")}"
    }

connection {
  type = "ssh"
  user = "devops"
  host = "${google_compute_instance.postgre2.network_interface.0.access_config.0.nat_ip}"
  agent = false
  private_key = "${file("~/.ssh/id_rsa")}"
        
 }

provisioner "remote-exec" {
    script = "pg_install.sh"
    }
 }
 resource "google_compute_instance" "postgre3" {
  name         = "pg-node3"
  machine_type = "e2-small"
  zone         = "us-central1-a"


  boot_disk {
     initialize_params {
       image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
      
   }


network_interface {
   network = "default"
   access_config {}
}

metadata = {
    ssh-keys = "devops:${file("~/.ssh/id_rsa.pub")}"
    }

connection {
  type = "ssh"
  user = "devops"
  host = "${google_compute_instance.postgre3.network_interface.0.access_config.0.nat_ip}"
  agent = false
  private_key = "${file("~/.ssh/id_rsa")}"
        
 }

provisioner "remote-exec" {
    script = "pg_install.sh"
    }
 }
 resource "google_compute_instance" "postgre4" {
  name         = "slave-node4"
  machine_type = "e2-small"
  zone         = "us-central1-a"


  boot_disk {
     initialize_params {
       image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
      
   }


network_interface {
   network = "default"
   access_config {}
}

metadata = {
    ssh-keys = "devops:${file("~/.ssh/id_rsa.pub")}"
    }

connection {
  type = "ssh"
  user = "devops"
  host = "${google_compute_instance.postgre4.network_interface.0.access_config.0.nat_ip}"
  agent = false
  private_key = "${file("~/.ssh/id_rsa")}"
        
 }

provisioner "remote-exec" {
    script = "pg_install.sh"
    }
 }