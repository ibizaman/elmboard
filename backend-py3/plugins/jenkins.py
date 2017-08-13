"""
Jenkins plugin.

Exports the jenkinsLoop function which connects to a jenkins instance
and send builds and builds updates to a given coroutine.
"""
import asyncio

from datetime import datetime, timedelta

import jenkins
import pytz


def connect(url, username, password, timezone):
    """
    Connects to a jenkins instance.

    @param url: url of the jenkins server.
    @type url: string.

    @param username: username with which to connect to the jenkins server.
    @type username: string.

    @param password: password with which to connect to the jenkins server.
    @type password: string.

    @param timezone: timezone of the jenkins server.
    @type timezone: string.
    """
    j = jenkins.Jenkins(url, username=username, password=password)
    j.timezone = pytz.timezone(timezone)
    return j


async def jenkinsLoop(j, target, poll_delay=10):
    """
    Send updated jenkins build info to a given coroutine target.

    @param j: connected jenkins instance
    @type j:

    @param target: coroutine receiving the build info and updates..
    @type target: coroutine.

    @param poll_delay: wait for given seconds between polls.
    @type poll_delay: int.
    """

    builds_cache = {}

    while True:
        for job in _get_jobs(j):
            for build in _get_job_builds(j, job):
                await asyncio.sleep(0.01)
                cache_key = (build['name'], build['build'])
                if (build['name'], build['build']) in builds_cache:
                    if builds_cache[cache_key]['status'] not in ['SUCCESSFUL', 'FAILED', 'ABORTED']:
                        info = _get_build_info(j, build, j.timezone)
                        if info in ['SUCCESSFUL', 'FAILED', 'ABORTED']:
                            builds_cache[cache_key] = info
                            target.send(info)
                else:
                    info = _get_build_info(j, build, j.timezone)
                    builds_cache[cache_key] = info
                    target.send(info)
        await asyncio.sleep(poll_delay)


def _get_jobs(j):
    jobs = j.get_jobs()
    for job in jobs:
        yield job


def _get_job_builds(j, job):
    for build in j.get_job_info(job['name'])['builds']:
        yield {
            'name': job['name'],
            'url': job['url'],
            'build': build['number'],
        }


def _get_build_info(j, build, timezone):
    info = j.get_build_info(build['name'], build['build'])

    start = datetime.fromtimestamp(info['timestamp']/1000, tz=timezone)

    if info['result']:
        end = start + timedelta(milliseconds=info['duration'])
        status = {
            'SUCCESS': 'SUCCESSFUL',
            'FAILURE': 'FAILED',
            'ABORTED': 'ABORTED',
        }[info['result']]
    elif info['building']:
        end = None
        status = 'RUNNING'
    else:
        end = start + timedelta(milliseconds=info['estimatedDuration'])
        status = 'SCHEDULED'

    return {
        'name': build['name'],
        'url':  build['url'],
        'build': build['build'],
        'status': status,
        'start': _to_timestamp(start),
        'end': _to_timestamp(end),
    }


def _to_timestamp(dt):
    if dt is None:
        return None
    return (dt.astimezone(pytz.utc) - datetime(1970, 1, 1, tzinfo=pytz.utc)).total_seconds() * 1000
