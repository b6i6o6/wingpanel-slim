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

    private const int SHADOW_SIZE = 4;

    // Positioning & Shape
    private int panel_height = 0;
    protected int panel_x;
    protected int panel_y;
    private int panel_width;
    protected int panel_displacement = 0;
    protected int panel_padding = 10;
    protected Gdk.Rectangle monitor_dimensions;
    protected Services.Settings.WingpanelSlimPanelEdge panel_edge = Services.Settings.WingpanelSlimPanelEdge.SLANTED;
    protected Services.Settings.WingpanelSlimPanelPosition panel_position = Services.Settings.WingpanelSlimPanelPosition.RIGHT;
    
    
    // Auto-hide & first animation
    protected bool auto_hide = false;
    protected bool first_run = true;
    protected bool submenu_drawn = false;
    private bool mouse_inside = false;
    private uint mouse_out_count = 0;
    private uint slide_in_timer = 0;
    private uint slide_out_timer = 0;
    private uint slide_out_delay = 0;
    
    
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
        
        // Watch for mouse
        add_events(EventMask.ENTER_NOTIFY_MASK | EventMask.LEAVE_NOTIFY_MASK);
        enter_notify_event.connect(mouse_entered);
        leave_notify_event.connect(mouse_left);
                
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
        
        
        if (panel_position == Services.Settings.WingpanelSlimPanelPosition.RIGHT)
            panel_x = monitor_dimensions.x + monitor_dimensions.width - size.width - 32;
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.MIDDLE)
            panel_x = monitor_dimensions.x + (monitor_dimensions.width / 2) - (size.width / 2);
        else if (panel_position == Services.Settings.WingpanelSlimPanelPosition.LEFT)
            panel_x = monitor_dimensions.x + 32;
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
        ctx.render_background (cr, size.x, size.y, size.width, size.height);
        
        // Slide in
        if (first_run) {
            first_run = false;
            slide_in_timer = Timeout.add (10, animation_move_in);
        }

        var child = get_child ();

        if (child != null)
            propagate_draw (child, cr);

        if (!shadow.visible)
            shadow.show_all ();
            
        return true;
    }

    private bool animation_move_in () {
        if (panel_displacement >= 0 ) {
            slide_in_timer = 0;
            return false;
        } else {
            panel_displacement += 1;
            move (panel_x, panel_y + panel_displacement);
            shadow.move (panel_x, panel_y + panel_height + panel_displacement);
            return true;
        }
    }
        
    private bool animation_move_out () {
        if (slide_in_timer > 0 || panel_displacement <= -panel_height+1 ) {
            return false;
        } else {
            panel_displacement -= 1;
            move (panel_x, panel_y + panel_displacement);
            shadow.move (panel_x, panel_y + panel_height + panel_displacement);
            return true;
        }
    }
    
    protected bool queue_move_out () {
        if (mouse_inside || submenu_drawn) {                            // If the mouse is inside, cancel the move out
            mouse_out_count = 0;
            slide_out_delay = 0;
            return false;
        } else {                                                        
            mouse_out_count++;
            if (mouse_out_count == 100){                                // If we have waited long enough, start the animation and stop the queue
                mouse_out_count = 0;
                slide_out_delay = 0;
                slide_out_timer = Timeout.add(20, animation_move_out);
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
         if (auto_hide) {
             mouse_inside = true;
             slide_in_timer = Timeout.add(10, animation_move_in);
         }
         return true;
    }

    public bool mouse_left(Gdk.EventCrossing e) {
        if (auto_hide) {
            mouse_inside = false;
            queue_move_out ();
        }
        return true;
    }

    private void on_monitors_changed () {
        panel_resize (true);
    }

    private void panel_resize (bool redraw) {
        screen.get_monitor_geometry (screen.get_primary_monitor(), out monitor_dimensions);
        
        Gtk.Allocation size;
        get_allocation (out size);
        
        panel_width = 1;
        panel_x = monitor_dimensions.x + monitor_dimensions.width - size.width - 32;
        panel_y = monitor_dimensions.y;

        move (panel_x, panel_y + panel_displacement);
        shadow.move (panel_x, panel_y + panel_height + panel_displacement);

        this.set_size_request (-1, 24);
        shadow.set_size_request (panel_width, SHADOW_SIZE);

        if (redraw)
            queue_draw ();
    }
}
