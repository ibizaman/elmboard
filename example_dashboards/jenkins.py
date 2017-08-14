import asyncio

from plugins import jenkins


def setup():
    url = 'http://localhost:8090'
    username = 'api'
    password = 'api'
    timezone = 'America/Los_Angeles'

    j = jenkins.connect(url, username, password, timezone)

    def run(loop, target, graph_id):
        return asyncio.gather(jenkins.jenkinsLoop(j, target), loop=loop)

    return {
        'run': run,
        'info': {
            'title': 'Sample Jenkins Example',
            'graphs': [{
                'title': 'Jenkins Builds ' + url,
                'type': 'builds',
                'job_prefix_url': 'http://localhost:8090/job/',
            }]
        }
    }
