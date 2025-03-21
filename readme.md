### Setup Instructions

First, [install terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

Then, [install AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

Then, run `terraform init` in the project directory.

Finally, run `terraform apply` to create the infrastructure. This will create all resources needed for the project, upload all code, package the models, and deploy the application.

To find the URL of the deployed application, open the AWS Console and navigate to API Gateway. The URL will be listed there.

### Interacting with the Application

Ensure that the `requests` library is installed. You can install it with `pip install requests`.

A client is located at `./client/main.py`. Run it with `python3 ./client/main.py` to interact with the deployed application.
