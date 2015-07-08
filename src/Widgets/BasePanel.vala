// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2014 Wingpanel Developers
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

using Gdk;

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

    protected Services.Settings settings { get; private set; }

    private const int SHADOW_SIZE = 4;
    private const int FALLBACK_FADE_DURATION = 150;
    private const int ELEMENTARY_SPACING = 60;

    private int panel_height = 0;
    private int panel_x;
    private int panel_y;
    private int panel_width;
    private int monitor_num;
    protected int panel_padding = 10;
    protected Gdk.Rectangle monitor_dimensions;
    protected Services.Settings.WingpanelSlimPanelEdge panel_edge = Services.Settings.WingpanelSlimPanelEdge.SLANTED;
    protected Services.Settings.WingpanelSlimPanelPosition panel_position = Services.Settings.WingpanelSlimPanelPosition.RIGHT;

    // Auto-hide animations
    protected bool entering_animation = true;
    private int panel_displacement = -40;
    private bool mouse_inside = false;
    private uint mouse_out_count = 0;
    private uint slide_in_timer = 0;
    private uint slide_out_timer = 0;
    private uint slide_out_delay = 0;

    private double legible_alpha_value = -1.0;
    private double panel_alpha = 0.0;
    private double panel_current_alpha = 0.0;
    private double initial_panel_alpha;
    private int fade_duration;
    private int64 start_time;

    private Settings? gala_settings = null;
    private enum Duration {
        DEFAULT,
        CLOSE,
        MINIMIZE,
        OPEN,
        SNAP,
        WORKSPACE
    }
    private int duration_values[6];

    private PanelShadow shadow = new PanelShadow ();
    private Wnck.Screen wnck_screen;

    public BasePanel (Services.Settings settings) {
        this.settings = settings;
        this.settings.changed.connect (on_settings_update);
        on_settings_update();

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

        // Watch for mouse
        add_events(EventMask.ENTER_NOTIFY_MASK | EventMask.LEAVE_NOTIFY_MASK);
        enter_notify_event.connect(mouse_entered);
        leave_notify_event.connect(mouse_left);

        destroy.connect (Gtk.main_quit);

        wnck_screen = Wnck.Screen.get_default ();
        wnck_screen.active_workspace_changed.connect (active_workspace_changed);
        wnck_screen.window_opened.connect ((window) => {
            if (window.get_window_type () == Wnck.WindowType.NORMAL) {
                window.state_changed.connect (window_state_changed);
                window.workspace_changed.connect (window_workspace_switched);

                update_panel_alpha (Duration.OPEN);
                if (window.is_maximized_vertically ())
                    window.geometry_changed.connect (window_geometry_changed_open);
            }
        });

        wnck_screen.window_closed.connect ((window) => {
            if (window.get_window_type () == Wnck.WindowType.NORMAL) {
                window.state_changed.disconnect (window_state_changed);
                window.workspace_changed.disconnect (window_workspace_switched);
                window.geometry_changed.disconnect (window_geometry_changed_open);
                window.geometry_changed.disconnect (window_geometry_changed_snap);

                update_panel_alpha (Duration.CLOSE);
            }
        });

        if ("org.pantheon.desktop.gala.animations" in Settings.list_schemas ()) {
            gala_settings = new Settings ("org.pantheon.desktop.gala.animations");
            gala_settings.changed.connect (get_duration_values);
        }

        get_duration_values ();

        update_panel_alpha (Duration.DEFAULT);
    }

    private void get_duration_values () {
        if (gala_settings != null) {
            if (gala_settings.get_boolean ("enable-animations")) {
                duration_values[Duration.DEFAULT] = FALLBACK_FADE_DURATION;
                duration_values[Duration.CLOSE] = gala_settings.get_int ("close-duration");
                duration_values[Duration.MINIMIZE] = gala_settings.get_int ("minimize-duration");
                duration_values[Duration.OPEN] = gala_settings.get_int ("open-duration");
                duration_values[Duration.SNAP] = gala_settings.get_int ("snap-duration");
                duration_values[Duration.WORKSPACE] = gala_settings.get_int ("workspace-switch-duration");
            } else {
                foreach (int val in duration_values)
                    val = 0;
            }
        } else {
            foreach (int val in duration_values)
                val = FALLBACK_FADE_DURATION;
        }
    }

    private void active_workspace_changed () {
        update_panel_alpha (Duration.WORKSPACE);
    }

    private void window_workspace_switched () {
        update_panel_alpha (Duration.DEFAULT);
    }

    private void window_state_changed (Wnck.Window window,
            Wnck.WindowState changed_mask, Wnck.WindowState new_state) {
        if (((changed_mask & Wnck.WindowState.MAXIMIZED_VERTICALLY) != 0
            || (changed_mask & Wnck.WindowState.MINIMIZED) != 0)
            && (window.get_workspace () == wnck_screen.get_active_workspace ()
            || window.is_sticky ())) {
            if ((new_state & Wnck.WindowState.MINIMIZED) != 0
                && (changed_mask & Wnck.WindowState.MINIMIZED) != 0) {
                update_panel_alpha (Duration.MINIMIZE);
            } else if ((new_state & Wnck.WindowState.MINIMIZED) == 0
                && (changed_mask & Wnck.WindowState.MINIMIZED) != 0) {
                update_panel_alpha (Duration.OPEN);
            } else if ((new_state & Wnck.WindowState.MAXIMIZED_VERTICALLY) != 0) {
                update_panel_alpha (Duration.SNAP);
                window.geometry_changed.connect (window_geometry_changed_snap);
            } else {
                update_panel_alpha (Duration.SNAP);
            }
        }
    }

    private void window_geometry_changed_open (Wnck.Window window) {
        if (window_fills_workarea (window)) {
            update_panel_alpha (Duration.OPEN);

            // Fix panel not updating when windows are moved quickly between displays.
            if (screen.get_n_monitors () > 1)
                window.geometry_changed.connect (window_geometry_changed_snap);
        } else if (!window.is_maximized_vertically ()) {
            window.geometry_changed.disconnect (window_geometry_changed_open);
        } else if (screen.get_n_monitors () > 1 && window.is_maximized_vertically ()) {
            int window_x, window_y;
            window.get_geometry (out window_x, out window_y, null, null);

            if (screen.get_monitor_at_point (window_x, window_y) != monitor_num)
                window.geometry_changed.disconnect (window_geometry_changed_open);
        }
    }

    private void window_geometry_changed_snap (Wnck.Window window) {
        if (window_fills_workarea (window)) {
            update_panel_alpha (Duration.SNAP);

            // Fix panel not updating when windows are moved quickly between displays.
            if (screen.get_n_monitors () == 1)
                window.geometry_changed.disconnect (window_geometry_changed_snap);
        } else if (!window.is_maximized_vertically ()) {
            window.geometry_changed.disconnect (window_geometry_changed_snap);
        }
    }

    private void window_geometry_changed_fullscreen (Wnck.Window window) {
        update_panel_alpha (Duration.DEFAULT);
        window.geometry_changed.disconnect (window_geometry_changed_fullscreen);
    }

    private bool window_fills_workarea (Wnck.Window window) {
        int scale_factor = this.get_scale_factor ();
        var monitor_workarea = screen.get_monitor_workarea (monitor_num);
        int monitor_workarea_x = monitor_workarea.x * scale_factor;
        int monitor_workarea_y = monitor_workarea.y * scale_factor;
        int monitor_workarea_width = monitor_workarea.width * scale_factor;
        int window_x, window_y, window_width, window_height;
        window.get_geometry (out window_x, out window_y, out window_width, out window_height);

        if (window.is_maximized_vertically () && !window.is_minimized ()
            && window_y == monitor_workarea_y
            && (window_x == monitor_workarea_x
            || window_x == monitor_workarea.x + monitor_workarea_width / 2)
            && (window_width == monitor_workarea_width
            || window_width == monitor_workarea_width / 2))
            return true;

        return false;
    }

    protected abstract Gtk.StyleContext get_draw_style_context ();

    public override void realize () {
        base.realize ();
        panel_resize (false);
    }

    public override bool draw (Cairo.Context cr) {
        Gtk.Allocation size;
        get_allocation (out size);

        if (panel_position == Services.Settings.WingpanelSlimPanelPosition.RIGHT)
            panel_x = monitor_dimensions.x + monitor_dimensions.width - size.width - ELEMENTARY_SPACING;
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.MIDDLE)
            panel_x = monitor_dimensions.x + (monitor_dimensions.width / 2) - (size.width / 2);
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.LEFT)
            panel_x = monitor_dimensions.x + ELEMENTARY_SPACING;
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.FLUSH_RIGHT)
            panel_x = monitor_dimensions.x + monitor_dimensions.width - size.width;
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.FLUSH_LEFT)
            panel_x = monitor_dimensions.x;

        move (panel_x, panel_y + panel_displacement);

        if (panel_height != size.height) {
            panel_height = size.height;
            message ("New Panel Height: %i", size.height);
            shadow.move (panel_x, panel_y + panel_height + panel_displacement);
        }

        var ctx = get_draw_style_context ();
        var background_color = ctx.get_background_color (Gtk.StateFlags.NORMAL);
        background_color.alpha = panel_current_alpha;
        Gdk.cairo_set_source_rgba (cr, background_color);
        cr.rectangle (size.x, size.y, size.width, size.height);
        cr.fill ();

        // Animation behavior on launch
        if (entering_animation) {
            entering_animation = false;
            if (settings.auto_hide) {
                // In auto_hide, get a glimpse of the panel before it disappears
                panel_displacement = 0;
                update_panel_position();
                queue_move_out();
            } else {
                // Otherwise, keep the original slide in behavior
                slide_in_timer = Timeout.add (300 / panel_height, animation_move_in);
            }
        }

        var child = get_child ();

        if (child != null)
            propagate_draw (child, cr);

        if (panel_alpha > 1E-3) {
            shadow.show ();
            shadow.show_all ();
        } else
            shadow.hide ();

        return true;
    }

    public void update_opacity (double alpha) {
        legible_alpha_value = alpha;
        update_panel_alpha (Duration.DEFAULT);
    }

    private void update_panel_alpha (Duration duration) {
        panel_alpha = settings.background_alpha;
        if (settings.auto_adjust_alpha) {
            if (active_workspace_has_maximized_window ())
                panel_alpha = 1.0;
            else if (legible_alpha_value >= 0)
                panel_alpha = legible_alpha_value;
        }

        if (panel_current_alpha != panel_alpha) {
            fade_duration = duration_values[duration];
            initial_panel_alpha = panel_current_alpha;
            start_time = 0;

            add_tick_callback (draw_timeout);
        }  
    }

    private bool draw_timeout (Gtk.Widget widget, Gdk.FrameClock frame_clock) {
        queue_draw ();

        if (fade_duration == 0) {
            panel_current_alpha = panel_alpha;

            return false;
        }

        if (start_time == 0) {
            start_time = frame_clock.get_frame_time ();

            return true;
        }

        if (initial_panel_alpha > panel_alpha) {
            panel_current_alpha = initial_panel_alpha - ((double) (frame_clock.get_frame_time () - start_time) 
            / (fade_duration * 1000)) * (initial_panel_alpha - panel_alpha);
            panel_current_alpha = double.max (panel_current_alpha, panel_alpha);
        } else if (initial_panel_alpha < panel_alpha) {
            panel_current_alpha = initial_panel_alpha + ((double) (frame_clock.get_frame_time () - start_time) 
            / (fade_duration * 1000)) * (panel_alpha - initial_panel_alpha);
            panel_current_alpha = double.min (panel_current_alpha, panel_alpha);
        }

        if (panel_current_alpha != panel_alpha)
            return true;

        return false;
    }

    private void update_panel_position() {
        move (panel_x, panel_y + panel_displacement);
        shadow.move (panel_x, panel_y + panel_height + panel_displacement);
    }

    private bool animation_move_in () {
        if (panel_displacement >= 0 ) {
            slide_in_timer = 0;
            return false;
        }

        panel_displacement += 1;
        update_panel_position();
        return true;
    }

    private bool animation_move_out () {
        if (slide_in_timer > 0 || panel_displacement <= -panel_height+1 ) {
            return false;
        } else {
            panel_displacement -= 1;
            update_panel_position();
            return true;
        }
    }

    protected bool queue_move_out () {
        if (mouse_inside) {                                             // If the mouse is inside, cancel the move out
            mouse_out_count = 0;
            slide_out_delay = 0;
            return false;
        } else {
            mouse_out_count++;
            if (mouse_out_count == 100){                                // If we have waited long enough, start the animation and stop the queue
                mouse_out_count = 0;
                slide_out_delay = 0;
                slide_out_timer = Timeout.add(300 / panel_height, animation_move_out);
                return false;
            } else if (slide_out_delay == 0) {                          // If this is the first call to this function, start the timer
                slide_out_delay = Timeout.add(10, queue_move_out);
                return true;
            } else {                                                    // keep chugging away
                return true;
            }
        }
    }

    public bool mouse_entered(Gdk.EventCrossing e) {
         if (settings.auto_hide) {
             mouse_inside = true;
             slide_in_timer = Timeout.add(300 / panel_height, animation_move_in);
         }
         return true;
    }

    public bool mouse_left(Gdk.EventCrossing e) {
        if (settings.auto_hide) {
            mouse_inside = false;
            queue_move_out ();
        }
        return true;
    }

    private bool active_workspace_has_maximized_window () {
        int scale_factor = this.get_scale_factor ();
        var workspace = wnck_screen.get_active_workspace ();
        var monitor_workarea = screen.get_monitor_workarea (monitor_num);
        int monitor_workarea_x = monitor_workarea.x * scale_factor;
        int monitor_workarea_y = monitor_workarea.y * scale_factor;
        int monitor_workarea_width = monitor_workarea.width * scale_factor;
        bool window_left = false, window_right = false;

        Gdk.Rectangle monitor_geometry;
        screen.get_monitor_geometry (monitor_num, out monitor_geometry);

        foreach (var window in wnck_screen.get_windows ()) {
            int window_x, window_y, window_width, window_height;
            window.get_geometry (out window_x, out window_y, out window_width, out window_height);

            if ((window.is_pinned () || window.get_workspace () == workspace)
                && window.is_maximized_vertically () && !window.is_minimized ()
                && window_y == monitor_workarea_y) {
                    if (window_x == monitor_workarea_x
                        && window_width == monitor_workarea_width)
                        return true;
                    else if (window_x == monitor_workarea_x
                        && window_width == monitor_workarea_width / 2)
                        window_left = true;
                    else if (window_x == monitor_workarea_x + monitor_workarea_width / 2
                        && window_width == monitor_workarea_width / 2)
                        window_right = true;

                    if (window_left && window_right)
                        return true;
            }

            if (window_x == monitor_geometry.x
                && window_y == monitor_geometry.y
                && window_width == monitor_geometry.width
                && window_height == monitor_geometry.height)
                window.geometry_changed.connect (window_geometry_changed_fullscreen);
        }

        return false;
    }

    private void on_monitors_changed () {
        panel_resize (true);
    }

    private void panel_resize (bool redraw) {
        monitor_num = screen.get_primary_monitor ();
        screen.get_monitor_geometry (monitor_num, out monitor_dimensions);

        // if we have multiple monitors, we must check if the panel would be placed inbetween
        // monitors. If that's the case we have to move it to the topmost, or we'll make the
        // upper monitor unusable because of the struts.
        // First check if there are monitors overlapping horizontally and if they are higher
        // our current highest, make this one the new highest and test all again
        if (screen.get_n_monitors () > 1) {
            Gdk.Rectangle dimensions;
            for (var i = 0; i < screen.get_n_monitors (); i++) {
                screen.get_monitor_geometry (i, out dimensions);
                if (((dimensions.x >= monitor_dimensions.x
                    && dimensions.x < monitor_dimensions.x + monitor_dimensions.width)
                    || (dimensions.x + dimensions.width > monitor_dimensions.x
                    && dimensions.x + dimensions.width <= monitor_dimensions.x + monitor_dimensions.width)
                    || (dimensions.x < monitor_dimensions.x
                    && dimensions.x + dimensions.width > monitor_dimensions.x + monitor_dimensions.width))
                    && dimensions.y < monitor_dimensions.y) {
                    warning ("Not placing wingpanel on the primary monitor because of problems" +
                        " with multimonitor setups");
                    monitor_dimensions = dimensions;
                    monitor_num = i;
                    i = 0;
                }
            }
        }

        Gtk.Allocation size;
        get_allocation(out size);

        panel_width = 1;
        panel_x = monitor_dimensions.x + monitor_dimensions.width - size.width - ELEMENTARY_SPACING;
        panel_y = monitor_dimensions.y;

        move (panel_x, panel_y + panel_displacement);
        shadow.move (panel_x, panel_y + panel_height + panel_displacement);

        this.set_size_request (-1, 24);
        shadow.set_size_request (panel_width, SHADOW_SIZE);

        if (redraw)
            queue_draw ();
    }

    private void on_settings_update() {
        this.panel_position = settings.panel_position;
        this.panel_edge = settings.panel_edge;

        // Replay the entering animation to reset the position according to the auto_hide setting
        entering_animation = true;
        queue_draw();
    }
}
