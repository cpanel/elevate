#!/bin/sh -l

set -x
terraform -v | head -n1
exec /bin/bash