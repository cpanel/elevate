#!/bin/sh -l

terraform -v | head -n1
terraform=$(terraform -v | head -n1);
echo "terraform=$terraform" >> $GITHUB_OUTPUT;
