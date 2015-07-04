// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2013 Wingpanel Developers
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

public class Wingpanel.App : Granite.Application {
    private IndicatorLoader indicator_loader;
    private Services.Settings settings;
    private Widgets.BasePanel panel;
    private Widgets.AppButtonPanel apps_button_panel;
    private Services.BackgroundManager background_manager;

    construct {
        build_data_dir = Build.DATADIR;
        build_pkg_data_dir = Build.PKGDATADIR;
        build_release_name = Build.RELEASE_NAME;
        build_version = Build.VERSION;
        build_version_info = Build.VERSION_INFO;

        program_name = "Wingpanel-slim";
        exec_name = "wingpanel-slim";
        application_id = "net.launchpad.wingpanel";
    }

    protected override void startup () {
        base.startup ();

#if !OLD_LIB_IDO
        Ido.init ();
#endif
        Services.EndSessionDialog.register ();

        indicator_loader = new Backend.IndicatorFactory (settings.blacklist);
        panel = new Widgets.Panel (this, settings, indicator_loader);

        panel.show_all ();

        background_manager = new Services.BackgroundManager (settings, panel.get_screen ());
        background_manager.update_background_alpha.connect (panel.update_opacity);

        apps_button_panel = new Widgets.AppButtonPanel (this, settings);
        this.settings.changed.connect (on_settings_update);
        on_settings_update ();
    }

    private void on_settings_update () {
        if (settings.show_launcher){
            apps_button_panel.show_all ();
        } else {
            apps_button_panel.hide ();
        }
    }

    protected override void activate () {
        panel.present ();
    }

    public static int main (string[] args) {
        return new Wingpanel.App ().run (args);
     }
}
