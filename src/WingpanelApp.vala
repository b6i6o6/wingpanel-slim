// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2011-2012 Wingpanel Developers
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

namespace Wingpanel {

    public class WingpanelApp : Granite.Application {
        private IndicatorLoader indicator_loader;
        private Services.Settings settings;
        private Widgets.BasePanel panel;

        construct {
            build_data_dir = Build.DATADIR;
            build_pkg_data_dir = Build.PKGDATADIR;
            build_release_name = Build.RELEASE_NAME;
            build_version = Build.VERSION;
            build_version_info = Build.VERSION_INFO;

            program_name = "Wingpanel";
            exec_name = "wingpanel";
            application_id = "net.launchpad.wingpanel";
        }

        protected override void activate () {
            debug ("Activating");

            if (get_windows () == null)
                init ();
        }

        private void init () {
            settings = new Services.Settings ();
            indicator_loader = new Backend.IndicatorFactory (settings);
            panel = new Widgets.Panel (this, settings, indicator_loader);

            panel.show_all ();
        }

        public static int main (string[] args) {
            return new WingpanelApp ().run (args);
        }
    }
}
