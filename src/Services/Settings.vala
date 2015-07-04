// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2013 Wingpanel Developers
  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program.  If not, see <http://www.gnu.org/licenses/>

  END LICENSE
***/

namespace Wingpanel.Services {
    public class Settings : Granite.Services.Settings {

        public enum WingpanelSlimPanelPosition {
            LEFT = 0,
            MIDDLE = 1,
            RIGHT = 2,
            FLUSH_LEFT = 3,
            FLUSH_RIGHT = 4
        }
        public WingpanelSlimPanelPosition panel_position { get; set; }
        
        public enum WingpanelSlimPanelEdge {
            SLANTED = 0,
            SQUARED = 1,
            CURVED_1 = 2,
            CURVED_2 = 3,
            CURVED_3 = 4
        }
        public WingpanelSlimPanelEdge panel_edge { get; set; }
        
        
        public string[] blacklist { get; set; }
        public bool auto_hide { get; set; }
        public bool show_launcher { get; set; }
        public string default_launcher { get; set; }
        public double background_alpha { get; set; }
        public bool auto_adjust_alpha { get; set; }

        public Settings () {
            base ("org.pantheon.desktop.wingpanel-slim");
        }
    }
}
