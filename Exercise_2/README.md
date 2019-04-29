Running Memcached / Redis Caches in ECS
==

Specification
--
To my mind the specification is somewhat ambiguous:

> Create two Service Unit files to start a Redis and Memcached docker container on an AWS ECS or EKS cluster

The phrase 'Service Unit Files' usually indicates to me a systemd configuration on a standard Linux machine; however given the text then goes on to talk about EKS and ECS, I believe that this is simply meant to indicate a more generic term for either an ECS Task Definition or a Kubernetes pod definition (for EKS).

AWS CLI
--

Most examples here are using the AWS CLI to manipulate the resources in AWS. Furthermore, I have assumed that a suitable ECS cluster already exists. If this is not the case, documentation on installing and configuring the AWS CLI is available at https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html. 

Information on setting up an ECS cluster is here: https://docs.aws.amazon.com/AmazonECS/latest/userguide/create_cluster.html

*NB* Because of the requirement for persistent storage, it is necessary to have EC2 backing for the ECS cluster - the newer _Fargate_ task type is unsuitable.


Task Definitions
--

Task Definitions have been provided as `redis_task_definition.json` and `memcached_task_definition.json`. The quickest way of importing these is via the AWS CLI:

```
$ aws ecs register-task-definition --cli-input-json "file://memcached_task_definition.json"

$ aws ecs register-task-definition --cli-input-json "file://redis_task_definition.json"
```

Both task definition files are reasonably similar, except that the Redis one defines a volume to be bound to the container, and changes the default startup command (to allow cache persistence across reboots).

Running the Tasks
--

Again we can use the AWS CLI to start the tasks:

`$ aws ecs run-task --task-definition redis-test --count 1 --cluster test-cluster`

`$ aws ecs run-task --task-definition memcached-test --count 1 --cluster test-cluster`

Where `test-cluster` is the name of your ECS cluster.

Stopping the Tasks 
--

We can see which tasks are running that belong to a particular family using:

`$ aws ecs list-tasks --family redis-test --cluster test-cluster`

To stop them:

`$ aws ecs stop-task --cluster test-cluster --task <TASK ARN>`

Replacing `<TASK ARN>` with the correct ARN supplied above.

Resiliency
--

Spawning tasks manually is fine, but if they are killed they will not restart. For this we need to define a service, like so:

`$ aws ecs create-service --cluster test-cluster --service-name redis-service --task-definition redis-test --desired-count 1`

Depending on the size of the ECS cluster (eg greater than one node), we may need to make use EFS to ensure all nodes in the ECS cluster can access the defined Docker volume used for snapshotting.

Connecting to Redis / populating data
--

There are a number of security and design questions that need to be answered before we can state definitively how to connect to the redis "cluster" (of one server). For the purposes of this example, Redis needs to be exposed from the ECS container host. I could spend hours on this topic, but best practice is going to be along the lines of:

- Bind the ECS service to a load balancer
- Expose the Redis port (6379) on the load balancer
- Set appropriate security groups such that only those hosts which need access to Redis can connect to it

However, for the purposes of this exercise I am going to assume that the service has been exposed on port 6379 on a given IP address in a secure / locked down manner.

I have provided a sample Python script which adds an additional key/value pair to Redis once every 5 minutes. It requires the Python `redis` library, which can be installed using `pip install redis` (though note that best practice is to install python modules in a virtual environment, using `venv`, `virtualenv`, `pipenv` or similar).

To run the script:

```
$ python3 redis_populate.py --hostname 127.0.0.1
```

(Note that the script will run with both Python 2 and Python 3 runtimes).
