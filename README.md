# caleb_liatrio_project
Interview project utilizing cloud natives tools.

CONTENTS OF THIS FILE
---------------------
 * Prerequisites
 * Installation
 * Cleanup
 * Maintainers

## Prerequisites

For this deploy, you will need the following:

-   An  [AWS account](https://portal.aws.amazon.com/billing/signup?nc2=h_ct&src=default&redirect_url=https%3A%2F%2Faws.amazon.com%2Fregistration-confirmation#/start)  with the IAM permissions listed on the  [EKS module documentation](https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/iam-permissions.md),
-   A configured [AWS CLI](https://aws.amazon.com/cli/)
	- Configuration [guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
-   [AWS IAM Authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
- [Terraform](https://www.terraform.io/downloads.html)
-   [kubectl](https://learn.hashicorp.com/tutorials/terraform/eks#kubectl)
-   [wget](https://www.gnu.org/software/wget/)
-   [Docker](https://docs.docker.com/get-docker/) (For uploading app image)
-   [Python](https://www.python.org/downloads/) (for testing)
	-  Also add the following `pip install pytest` and `pip install requests`
## Installation
**Optional**
If changes are required for the [App](https://github.com/cjobe026/caleb_liatrio_project/tree/main/docker)
Then upload it to the docker registry
`docker push cjobe026/api_project:1.0`

Navigate to the terraform folder
`cd terraform`

Run terraform init and apply
`terraform init`
`terraform apply`

Confirm the application is running by acquiring the LB output url and passing it to pytest.
`cd ..`
`python -m pytest --url <url>`

For monitoring results check the canary on [AWS Cloudwatch](https://aws.amazon.com/cloudwatch/).

**Optional**
Use the output region and cluster in the following command to configure the Kubectl
`aws eks --region <aws region> update-kubeconfig --name <cluster name>`

verify that kubernetes pods have started
`kubectl get pods`

## Cleanup
This will remove all components created during the deploy
`terraform destroy`

 ## Current maintainers:
 * Caleb Jobe(cjobe026) - https://github.com/cjobe026
