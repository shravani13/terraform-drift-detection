include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../modules//ecs_webstack"
}

# Inject lightweight dev constraints
inputs = {
  environment        = "dev"
  vpc_id             = "vpc-dev-67890"
  public_subnet_ids  = ["subnet-dev-pub-1", "subnet-dev-pub-2"]
  private_subnet_ids = ["subnet-dev-priv-1", "subnet-dev-priv-2"]
  
  desired_count   = 1 # Keep it lean and cheap
  #container_image = "nginxdemos/hello:latest"
}
