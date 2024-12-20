provider "aws" {
  region = "eu-west-1"  # You can change this to the AWS region of your choice
}

resource "aws_instance" "web_server" {
  ami           = "ami-0e9085e60087ce171"  # Update with the appropriate AMI ID for Ubuntu in your region
  instance_type = "t2.micro"
  key_name      = "Terraform-SSS"  # Replace with your SSH key pair name

  # User data script to install Apache, MySQL, create database and table
  user_data = <<-EOF
            #!/bin/bash
            # Update system packages
            apt update -y
            apt upgrade -y

            # Install Apache Web Server
            apt install -y apache2

            apt install -y s3fs

            # Install MySQL server
            apt install -y mysql-server

            # Start MySQL service
            systemctl start mysql

            # Enable MySQL to start on reboot
            systemctl enable mysql

            # Secure MySQL installation (simple setup for demo)
            sed -i 's/^bind-address\s*=.*$/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
            systemctl restart mysql

            mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('rootroot');"
            mysql -e "DELETE FROM mysql.user WHERE User='';"
            mysql -e "DROP DATABASE IF EXISTS test;"
            mysql -e "FLUSH PRIVILEGES;"

            # Create 'filedb' database and 'files' table
            mysql -uroot -prootroot -e "CREATE DATABASE filedb;"
            mysql -uroot -prootroot -e "
            USE filedb;
            CREATE TABLE files (
                id INT AUTO_INCREMENT PRIMARY KEY,
                filename VARCHAR(255) NOT NULL,
                file_size INT NOT NULL,
                upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );"

            mysql -uroot -prootroot -e "CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED WITH mysql_native_password BY 'tobeornot';"
            mysql -uroot -prootroot -e "GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;"
            mysql -uroot -prootroot -e "FLUSH PRIVILEGES;"

            # Start Apache server
            systemctl start apache2
            systemctl enable apache2

            # Install AWS CLI via curl
            sudo apt install curl unzip -y
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            unzip awscliv2.zip
            sudo ./aws/install
            rm awscliv2.zip

            aws configure set aws_access_key_id #Add your access key 
            aws configure set aws_secret_access_key #Add your private access key 
            aws configure set region eu-west-1

            # Create a directory to mount the S3 bucket
            mkdir /mnt/s3bucket

            # Mount the S3 bucket to EC2 instance using s3fs
            echo "Add private access key" > /etc/passwd-s3fs
            chmod 600 /etc/passwd-s3fs

            # Mount the S3 bucket to EC2 instance using s3fs (assuming role-based access)
            s3fs monika-terraformsss /mnt/s3bucket -o allow_other,umask=000

            # Create symbolic link to Apache's webroot
            ln -s /mnt/s3bucket /var/www/html/

            chown -R www-data:www-data /mnt/s3bucket
            chmod -R 755 /mnt/s3bucket

            # Set correct permissions
            sudo chown -R www-data:www-data /var/www/html/
            sudo chmod -R 755 /var/www/html/

            sudo chown -R www-data:www-data /var/www/html/s3bucket/
            sudo chmod -R 755 /var/www/html/s3bucket/

            # Optional: Set up cron job to sync S3 to Apache webroot periodically (every 1 minute)
            echo "*/1 * * * * /usr/bin/aws s3 sync s3://monika-terraformsss /var/www/html/ --exact-timestamps" >> /etc/crontab

            # Restart Apache2 to apply changes
            systemctl restart apache2
              EOF

  tags = {
    Name = "WebServer"
  }

  # Security Group to allow HTTP, MySQL, and SSH
  security_groups = ["ec2_mysql_sg"]
}

resource "aws_security_group" "web_sg" {
  name        = "web_sg"
  description = "Allow inbound and outbound traffic from anywhere"

  # Inbound rule allowing all traffic from anywhere (any port, any protocol)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all inbound traffic from anywhere
  }

  # Outbound rule allowing all traffic to anywhere (any port, any protocol)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic to anywhere
  }
}


