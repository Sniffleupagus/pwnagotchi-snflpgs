#
# Morse Code for pwnagotchi
#
# extending the led.py plugin to blink messages
# in morse code
#

from threading import Event
import _thread
import logging
import time

import pwnagotchi.plugins as plugins
from pwnagotchi.ui.components import LabeledValue
from pwnagotchi.ui.view import BLACK
import pwnagotchi.ui.fonts as fonts


class MorseCode(plugins.Plugin):
    __author__ = 'evilsocket@gmail.com'
    __version__ = '1.0.0'
    __license__ = 'GPL3'
    __description__ = 'An example plugin for pwnagotchi that implements all the available callbacks.'

    # Dictionary representing the morse code chart
    MORSE_CODE_DICT = { 'A':'.-', 'B':'-...',
                        'C':'-.-.', 'D':'-..', 'E':'.',
                        'F':'..-.', 'G':'--.', 'H':'....',
                        'I':'..', 'J':'.---', 'K':'-.-',
                        'L':'.-..', 'M':'--', 'N':'-.',
                        'O':'---', 'P':'.--.', 'Q':'--.-',
                        'R':'.-.', 'S':'...', 'T':'-',
                        'U':'..-', 'V':'...-', 'W':'.--',
                        'X':'-..-', 'Y':'-.--', 'Z':'--..',
                        '1':'.----', '2':'..---', '3':'...--',
                        '4':'....-', '5':'.....', '6':'-....',
                        '7':'--...', '8':'---..', '9':'----.',
                        '0':'-----', ', ':'--..--', '.':'.-.-.-',
                        '?':'..--..', '/':'-..-.', '-':'-....-',
                        '(':'-.--.', ')':'-.--.-'}

    def _convert_code(self, msg):
        didah = ''
        for l in msg:
            l = l.upper()
            if l in self.MORSE_CODE_DICT:
                didah += self.MORSE_CODE_DICT[l] + ' '
            else:
                # add a space for unknown characters
                didah += ' '
        return didah

    def _blink(self, msg):
        if len(msg) > 0:
            pattern = self._convert_code(msg)
            logging.info("[MORSE] '%s' -> '%s'" % (msg, pattern))

            # blank led for one measure ahead of message
            self._led(1)
            time.sleep(7 * self._delay / 1000.0)

            for c in pattern:
                if c == '.':
                    self._led(0)
                    time.sleep(self._delay / 1000.0)
                    self._led(1)
                    time.sleep(self._delay / 1000.0)
                elif c == '-':
                    self._led(0)
                    time.sleep(3 * self._delay / 1000.0)
                    self._led(1)
                    time.sleep(self._delay / 1000.0)
                elif c == ' ':
                    time.sleep(2 * self._delay / 1000.0)
                else:
                    # unexpected character... skip it
                    pass

            # blank period to end message
            self._led(1)
            time.sleep(7 * self._delay / 1000.0)
            # and back on
            self._led(0)
            logging.info("[MORSE] sent '%s' -> '%s'" % (msg, pattern))

    # thread stuff copied from plugins/default/led.py

    # queue a message
    #   but if there is one already (busy) then don't
    def _queue_message(self, message):
        if not self._is_busy:
            self._message = message
            self._event.set()
            logging.info("[Morse] message '%s' set", message)
        else:
            logging.info("[Morse] skipping '%s' because the worker is busy", message)

    def _led(self, on):
        with open(self._led_file, 'wt') as fp:
            fp.write(str(on))

    def _worker(self):
        logging.info("[Morse] worker started")
        while True:
            self._event.wait()
            self._event.clear()
            self._is_busy = True

            try:
                self._blink(self._message)
            except Exception as e:
                logging.exception("[Morse] error while blinking")

            finally:
                self._is_busy = False

    
    def __init__(self):
        logging.debug("[Morse] Code plugin initializing")
        self._is_busy = False
        self._event = Event()
        self._message = None
        self._led_file = "/sys/class/leds/led0/brightness"
        self._delay = 200


    # called when http://<host>:<port>/plugins/<plugin>/ is called
    # must return a html page
    # IMPORTANT: If you use "POST"s, add a csrf-token (via csrf_token() and render_template_string)
    def on_webhook(self, path, request):
        logging.info("[Morse] Web hook: %s" % repr(request))
        return "<html><body>Woohoo!</body></html>"

    # called when the plugin is loaded
    def on_loaded(self):
        try:
            logging.info("[Morse] loaded" % self.options)

            _thread.start_new_thread(self._worker, ())

            try:
                self._led_file = "/sys/class/leds/led%d/brightness" % int(self.options['led'])
            except Exception as err:
                self._led_file = "/sys/class/leds/led0/brightness"

            self._delay = int(self.options['delay'])

            logging.info("[Morse] plugin loaded for %s" % self._led_file)
            self._queue_message('loaded')
        except Exception as err:
            logging.warn("[Morse] Load failed: %s" % repr(err))

    # called before the plugin is unloaded
    def on_unload(self, ui):
        pass

    # called when there's internet connectivity
    def on_internet_available(self, agent):
        pass

    # called when the hardware display setup is done, display is an hardware specific object
    def on_display_setup(self, display):
        pass

    # called when everything is ready and the main loop is about to start
    def on_ready(self, agent):
        self._queue_message("READY O K")
        # you can run custom bettercap commands if you want
        #   agent.run('ble.recon on')
        # or set a custom state
        #   agent.set_bored()

    # called when the AI finished loading
    def on_ai_ready(self, agent):
        self._queue_message("AI READY")
        pass

    # called when the AI finds a new set of parameters
    def on_ai_policy(self, agent, policy):
        pass

    # called when the AI starts training for a given number of epochs
    def on_ai_training_start(self, agent, epochs):
        pass

    # called after the AI completed a training epoch
    def on_ai_training_step(self, agent, _locals, _globals):
        pass

    # called when the AI has done training
    def on_ai_training_end(self, agent):
        pass

    # called when the AI got the best reward so far
    def on_ai_best_reward(self, agent, reward):
        self._queue_message("WOOHOO")
        pass

    # called when the AI got the worst reward so far
    def on_ai_worst_reward(self, agent, reward):
        self._queue_message("MEH")
        pass

    # called by bettercap events
    def on_bc_event(self, agent, event):
        pass
    
    # called when a non overlapping wifi channel is found to be free
    def on_free_channel(self, agent, channel):
        pass

    # called when the status is set to bored
    def on_bored(self, agent):
        pass

    # called when the status is set to sad
    def on_sad(self, agent):
        self._queue_message("SAD!!!")
        pass

    # called when the status is set to excited
    def on_excited(self, agent):
        pass

    # called when the status is set to lonely
    def on_lonely(self, agent):
        pass

    # called when the agent is rebooting the board
    def on_rebooting(self, agent):
        self._queue_message("HASTA LAVISTA BABY")
        pass

    # called when the agent is waiting for t seconds
    def on_wait(self, agent, t):
        pass

    # called when the agent is sleeping for t seconds
    def on_sleep(self, agent, t):
        pass

    # called when the agent refreshed its access points list
    def on_wifi_update(self, agent, access_points):
        pass

    # called when the agent refreshed an unfiltered access point list
    # this list contains all access points that were detected BEFORE filtering
    def on_unfiltered_ap_list(self, agent, access_points):
        pass

    # called when the agent is sending an association frame
    def on_association(self, agent, access_point):
        self._queue_message("ASSOC")
        pass

    # called when the agent is deauthenticating a client station from an AP
    def on_deauthentication(self, agent, access_point, client_station):
        self._queue_message("PWNED")
        pass

    # callend when the agent is tuning on a specific channel
    def on_channel_hop(self, agent, channel):
        pass

    # called when a new handshake is captured, access_point and client_station are json objects
    # if the agent could match the BSSIDs to the current list, otherwise they are just the strings of the BSSIDs
    def on_handshake(self, agent, filename, access_point, client_station):
        self._queue_message("HI FRIEND")
        pass

    # called when an epoch is over (where an epoch is a single loop of the main algorithm)
    def on_epoch(self, agent, epoch, epoch_data):
        pass

    # called when a new peer is detected
    def on_peer_detected(self, agent, peer):
        self._queue_message("HI FRIEND")
        pass

    # called when a known peer is lost
    def on_peer_lost(self, agent, peer):
        self._queue_message("BYE FRIEND")
        pass
