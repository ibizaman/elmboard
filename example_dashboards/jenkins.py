import asyncio
from functools import partial

from plugins import jenkins


def setup(loop, target):
    url = 'http://localhost:8090'
    username = 'api'
    password = 'api'
    timezone = 'America/Los_Angeles'

    return {
        'title': 'Sample Jenkins Example',
        'graphs': [{
            'id': 1,
            'title': 'Jenkins Builds ' + url,
            'type': 'builds',
            'job_prefix_url': 'http://localhost:8090/job/',
            'task': asyncio.gather(jenkins.jenkinsLoop((partial(target, graph=1)()), url, username, password, timezone), loop=loop)
        }]
    }
