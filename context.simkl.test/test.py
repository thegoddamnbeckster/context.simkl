# -*- coding: utf-8 -*-

import xbmc

if __name__ == '__main__':
	xbmc.log("[SIMKL TEST] Context menu triggered!", xbmc.LOGINFO)
	xbmc.executebuiltin('Notification(SIMKL TEST, Context menu works!, 5000)')
