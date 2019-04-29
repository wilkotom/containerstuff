import redis
import string
import argparse

from time import time, sleep
from random import randint, choice

parser = argparse.ArgumentParser(description='Store randomly generated passwords in Redis.')
parser.add_argument('-H', '--hostname', default='localhost')
args = parser.parse_args()

r = redis.Redis(host=args.hostname, port=6379)
while True:
    characters = string.ascii_letters + string.punctuation  + string.digits
    password =  "".join(choice(characters) for x in range(randint(8, 16)))
    timestamp = int(time())
    r.set("{}".format(timestamp), password)
    print("Stored data with key {}".format(timestamp))
    sleep(300)
    