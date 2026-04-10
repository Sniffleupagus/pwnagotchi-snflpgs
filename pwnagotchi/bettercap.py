import json
import logging
import requests

import websockets
import websockets.exceptions
import asyncio

from requests.auth import HTTPBasicAuth


def decode(r, verbose_errors=True):
    try:
        return r.json()
    except Exception as e:
        if r.status_code == 200:
            logging.error("error while decoding json: error='%s' resp='%s'" % (e, r.text))
        else:
            err = "error %d: %s" % (r.status_code, r.text.strip())
            if verbose_errors:
                logging.info(err)
                # moved the raise under here..  it was even with "if"
                raise Exception(err)
        return r.text


class Client(object):
    def __init__(self, hostname='localhost', scheme='http', port=8081, username='user', password='pass'):
        self.hostname = hostname
        self.scheme = scheme
        self.port = port
        self.username = username
        self.password = password
        self.url = "%s://%s:%d/api" % (scheme, hostname, port)
        self.websocket = "ws://%s:%s@%s:%d/api" % (username, password, hostname, port)
        self.auth = HTTPBasicAuth(username, password)

    # session takes optional argument to pull a sub-dictionary
    #  ex.: "session/wifi", "session/ble"
    def session(self, sess="session"):
        r = requests.get("%s/%s" % (self.url, sess), auth=self.auth)
        return decode(r)

    async def start_websocket(self, consumer):
        s = "%s/events" % self.websocket
        restart_monitor = False
        while True:
            try:
                async with websockets.connect(s, timeout=10, ping_interval=60, ping_timeout=90) as ws:
                    if restart_monitor:
                        logging.info("bettercap reconnected, resetting wifi settings")
                        self._reset_wifi_settings()
                        if self.mode != 'manual':
                            self.run('wifi.recon on')
                        restart_monitor = False

                    async for msg in ws:
                        try:
                            await consumer(msg)
                        except Exception as ex:
                            logging.error("error while parsing bettercap event (%s)", ex)
            except asyncio.TimeoutError:
                logging.error("bettercap websocket timed out, reconnecting...")
            except websockets.exceptions.ConnectionClosedError as e:
                logging.error("bettercap websocket connection closed (%s), reconnecting...", e)
            except websockets.exceptions.WebSocketException as e:
                logging.error("bettercap websocket exception (%s), reconnecting...", e)
            except Exception as e:
                logging.exception("bettercap websocket error (%s), reconnecting...", e)

            restart_monitor = True
            await asyncio.sleep(5)

    def run(self, command, verbose_errors=True):
        r = requests.post("%s/session" % self.url, auth=self.auth, json={'cmd': command})
        try:
            return decode(r, verbose_errors=verbose_errors)
        except Exception as e:
            if "wifi is not running" in ("%s" % e):
                try:
                    self.run("wifi.recon on")
                except Exception as e2:
                    logging.exception("%s, after %s decoding: %s" % (e2, e, repr(r)))
            elif "is an unknown BSSID" in ("%s" % e):
                logging.debug(e)
                raise   # back to assoc or deauth
            else:
                logging.exception(e)
