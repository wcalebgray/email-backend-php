#!/bin/bash
# Deploys by using the following:
# - check which branch I'm on
# - build docker image
# - tag docker image
# - push docker image
# - create new task definition revision
# - Update service

APP="email-backend-php"
URL="461781854431.dkr.ecr.us-west-2.amazonaws.com"
CLUSTER="default"
REPO="$URL/$APP"
LOCAL_REPO="$APP"
TASK="$APP"


# exit on any error
set -e

# # semver may be in node_modules
# PATH="$PATH:node_modules/.bin"

# Check which branch I'm on and set environment based on branch
if [ -z "$GIT_BRANCH" ]; then
  branch=`git rev-parse --abbrev-ref HEAD`
else
  branch=`echo "$GIT_BRANCH" | awk -F/ '{ print $NF }'`
fi

if [ "$branch" = "production" ]; then
  env="production"
else
  env="stage"
fi

# build docker
echo "Building docker image for $env"
docker build -t "$LOCAL_REPO" .

# determine primary tag
tag=`git describe --abbrev=0`
build_number=`git rev-list "$tag".. --count`
if [ "$build_number" = "0" ]; then
  tag=`semver "$tag"`
else
  tag=`semver "$tag" -i prerelease`".$build_number"
fi

# login to docker repository
echo
echo "Logging in to AWS docker"
`aws ecr get-login | sed 's/-e none//'`

# push docker tags
echo
echo "Pushing docker tag: $tag"
image="$REPO:$tag"
docker tag "$LOCAL_REPO:latest" "$image"
docker push "$image"

echo
echo "Updating task: $TASK"

current_def=`aws ecs describe-task-definition --task-def "$TASK"`
# pull current task definition and replace the image(s)
current_containers=`node -pe "JSON.stringify(JSON.parse(process.argv[1]).taskDefinition.containerDefinitions)" "$current_def"`
new_containers=`echo "$current_containers" | sed "s~$REPO:[A-Za-z0-9._-]*~$image~g"`

# create a new revision of the task family
aws ecs register-task-definition --family $TASK --container-definitions "$new_containers" > /dev/null

echo "Updating $TASK service of cluster: $CLUSTER"
aws ecs update-service --cluster $CLUSTER --service $TASK --task-definition $TASK > /dev/null

echo 'Finished'