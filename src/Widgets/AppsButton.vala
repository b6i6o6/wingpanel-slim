// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011-2012 Wingpanel Developers
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Wingpanel.Widgets {

    public class AppsButton : IndicatorButton {
        private bool _active = false;
        public bool active {
            get {
                return _active;
            }
            set {
                _active = value;
                update_state_flags ();
            }
        }

        private Services.AppLauncherService? launcher_service = null;
        private Services.Settings settings;

        public AppsButton (Services.Settings settings) {
            this.settings = settings;
            this.can_focus = true;

            set_widget (WidgetSlot.LABEL, new Gtk.Label (_("Applications")));
            active = false;

            get_style_context ().add_class (StyleClass.APP_BUTTON);

            launcher_service = new Services.AppLauncherService (settings);
            launcher_service.launcher_state_changed.connect (on_launcher_state_changed);

            on_settings_update ();
            settings.changed.connect (on_settings_update);
        }

        private void on_launcher_state_changed (bool visible) {
            debug ("Launcher visibility changed to %s", visible.to_string ());
            active = visible;
        }

        public override bool button_press_event (Gdk.EventButton event) {
            launcher_service.launch_launcher ();
            return true;
        }

        /**
         * Make sure the menuitem appears to be selected even if the focus moves
         * to the client launcher app being displayed.
         */
        public override void state_flags_changed (Gtk.StateFlags flags) {
            update_state_flags ();
        }

        private void update_state_flags () {
            const Gtk.StateFlags ACTIVE_FLAGS = Gtk.StateFlags.PRELIGHT;

            if (active)
                set_state_flags (ACTIVE_FLAGS, true);
            else
                unset_state_flags (ACTIVE_FLAGS);
        }

        private void on_settings_update () {
            bool visible = settings.show_launcher;
            set_no_show_all (!visible);

            if (visible)
                show_all ();
            else
                hide ();
        }
    }
}
