provider "google" {
    project = var.GCP_PROJECT
    region  = "us-west1"
    zone    = "us-west1-b"
    credentials = var.GCP_CREDENTIALS 
}
# ------------------------------------------------------
# Local variables
# ------------------------------------------------------
locals {
    num_instances = 1
}
# ------------------------------------------------------
# Basic networking
# ------------------------------------------------------
data "google_compute_network" "default" {
    name = "default"
}
resource "random_id" "firewall_id" {
    byte_length = 4
}
resource "google_compute_firewall" "postgres" {
    name = "rt-dwh-postgres-firewall-${random_id.firewall_id.hex}"
    network = data.google_compute_network.default.name
    source_ranges = [ "0.0.0.0/0" ]
    direction = "INGRESS"
    allow {
        protocol = "tcp"
        ports = [ "5432" ]
    }
}
# ------------------------------------------------------
# Intance os
# ------------------------------------------------------
data "google_compute_image" "os" {
    project = "centos-cloud"
    family = "centos-7"
}
# ------------------------------------------------------
# 'Customers' instance
# ------------------------------------------------------
resource "random_id" "customers_id" {
    count = local.num_instances
    byte_length = 4
}
resource "google_compute_instance" "postgres_customers" {
    count = local.num_instances
    name = "rt-dwh-postgres-customers-${random_id.customers_id[count.index].hex}"
    machine_type = "e2-standard-2"
    boot_disk {
        initialize_params {
            image = data.google_compute_image.os.self_link
        }
    }
    network_interface {
        network = "default"
        access_config {}
    }
    metadata = {
        startup-script = file("../scripts/pg_customers_bootstrap.sh")
    }
}
# ------------------------------------------------------
# 'Products' instance
# ------------------------------------------------------
resource "random_id" "products_id" {
    count = local.num_instances
    byte_length = 4
}
resource "google_compute_instance" "postgres_products" {
    count = local.num_instances
    name = "rt-dwh-postgres-products-${random_id.products_id[count.index].hex}"
    machine_type = "e2-standard-2"
    boot_disk {
        initialize_params {
            image =data.google_compute_image.os.self_link
        }
    }
    network_interface {
        network = "default"
        access_config {}
    }
    metadata = {
        startup-script = file("../scripts/pg_products_bootstrap.sh")
    }
}