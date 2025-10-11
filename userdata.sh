#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${cluster_name} --container-runtime ${container_runtime}