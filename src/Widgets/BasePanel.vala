// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//  
//  Copyright (C) 2011-2013 Wingpanel Developers
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

public abstract class Wingpanel.Widgets.BasePanel : Gtk.Window {
    private enum Struts {
        LEFT,
        RIGHT,
        TOP,
        BOTTOM,
        LEFT_START,
        LEFT_END,
        RIGHT_START,
        RIGHT_END,
        TOP_START,
        TOP_END,
        BOTTOM_START,
        BOTTOM_END,
        N_VALUES
    }

    private const int SHADOW_SIZE = 4;

    private int panel_height = 0;
    private int panel_x;
    private int panel_y;
    private int panel_width;
    private int panel_displacement = -40;
    private uint animation_timer = 0;

    private PanelShadow shadow = new PanelShadow ();

    public BasePanel () {
        decorated = false;
        resizable = false;
        skip_taskbar_hint = true;
        app_paintable = true;
        set_visual (get_screen ().get_rgba_visual ());
        set_type_hint (Gdk.WindowTypeHint.DOCK);

        panel_resize (false);

        // Update the panel size on screen size or monitor changes
        screen.size_changed.connect (on_monitors_changed);
        screen.monitors_changed.connect (on_monitors_changed);

        destroy.connect (Gtk.main_quit);
    }

    protected abstract Gtk.StyleContext get_draw_style_context ();

    public override void realize () {
        base.realize ();
        panel_resize (false);
    }

    public override bool draw (Cairo.Context cr) {
        Gtk.Allocation size;
        get_allocation (out size);

        if (panel_height != size.height) {
            panel_height = size.height;
            message ("New Panel Height: %i", size.height);
            shadow.move (panel_x, panel_y + panel_height + panel_displacement);
            set_struts ();
        }

        var ctx = get_draw_style_context ();
        ctx.render_background (cr, size.x, size.y, size.width, size.height);

        // Slide in
        if (animation_timer == 0) {
            panel_displacement = -panel_height;
            animation_timer = Timeout.add (300 / panel_height, animation_callback);
        }

        var child = get_child ();

        if (child != null)
            propagate_draw (child, cr);

        if (!shadow.visible)
            shadow.show_all ();

        return true;
    }

    private bool animation_callback () {
        if (panel_displacement >= 0 ) {
            return false;
        } else {
            panel_displacement += 1;
            move (panel_x, panel_y + panel_displacement);
            shadow.move (panel_x, panel_y + panel_height + panel_displacement);
            return true;
        }
    }

    private void on_monitors_changed () {
        panel_resize (true);
    }

    private void set_struts () {
        if (!get_realized ())
            return;

        // Since uchar is 8 bits in vala but the struts are 32 bits
        // we have to allocate 4 times as much and do bit-masking
        var struts = new ulong[Struts.N_VALUES];

        struts[Struts.TOP] = panel_height + panel_y;
        struts[Struts.TOP_START] = panel_x;
        struts[Struts.TOP_END] = panel_x + panel_width;

        var first_struts = new ulong[Struts.BOTTOM + 1];
        for (var i = 0; i < first_struts.length; i++)
            first_struts[i] = struts[i];

        unowned X.Display display = Gdk.X11Display.get_xdisplay (get_display ());
        var xid = Gdk.X11Window.get_xid (get_window ());

        display.change_property (xid, display.intern_atom ("_NET_WM_STRUT_PARTIAL", false), X.XA_CARDINAL,
                                 32, X.PropMode.Replace, (uchar[]) struts, struts.length);
        display.change_property (xid, display.intern_atom ("_NET_WM_STRUT", false), X.XA_CARDINAL,
                                 32, X.PropMode.Replace, (uchar[]) first_struts, first_struts.length);
    }

    private void panel_resize (bool redraw) {
        Gdk.Rectangle monitor_dimensions;

        screen.get_monitor_geometry (screen.get_primary_monitor(), out monitor_dimensions);

        panel_x = monitor_dimensions.x;
        panel_y = monitor_dimensions.y;
        panel_width = monitor_dimensions.width;

        move (panel_x, panel_y + panel_displacement);
        shadow.move (panel_x, panel_y + panel_height + panel_displacement);

        this.set_size_request (panel_width, -1);
        shadow.set_size_request (panel_width, SHADOW_SIZE);

        set_struts ();

        if (redraw)
            queue_draw ();
    }
}
