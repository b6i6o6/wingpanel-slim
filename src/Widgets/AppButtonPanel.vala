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

namespace Wingpanel.Widgets {

    public class AppButtonPanel : BasePanel {
        private Gtk.Box container;
        
        private AppsButton apps_button;
        private MenuBar menubar;
        

        public AppButtonPanel (Wingpanel.App app, Services.Settings settings) {
            base(settings);
            set_application (app as Gtk.Application);
            
            this.settings = settings;
            this.settings.changed.connect (on_settings_update);
            on_settings_update();

            container = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            container.set_homogeneous (false);
     
            add (container);

            var style_context = get_style_context ();
            style_context.add_class (StyleClass.PANEL);
            style_context.add_class (Gtk.STYLE_CLASS_MENUBAR);

            // Add default widgets
            add_defaults (settings);
        }

        protected override Gtk.StyleContext get_draw_style_context () {
            return menubar.get_style_context ();
        }

        private void add_defaults (Services.Settings settings) {            
            // Menubar for storing the button
            menubar = new MenuBar ();
            apps_button = new Widgets.AppsButton (settings);
            
            
            apps_button.state_flags_changed.connect(apps_state_changed);
            
            menubar.append (apps_button);
            container.pack_end(menubar, false, false, panel_padding);
        }
    
        private void apps_state_changed(){
            submenu_drawn = apps_button.active;
            
            // Hack: "encourage" the menu to reevaluate if it needs to auto hide
            //if (!submenu_drawn){
            //    mouse_left(Gdk.EventCrossing ());
            //}
        }
        
        public override bool draw (Cairo.Context cr) {
            base.draw(cr);
            draw_background(cr);
            
            // force move it to the top left; no customization here
            panel_x = monitor_dimensions.x + 32;
            move (panel_x, panel_y + panel_displacement);
            
            return true;
        }
    
    
        private bool draw_background (Cairo.Context context) {
            Gtk.Allocation size;
            get_allocation (out size);
        
            // bg is already drawn by the css file, we need to specify which areas should be hidden
            draw_mask(context, 0, 0, size.width, size.height, panel_padding);
            context.clip ();
        
            context.set_source_rgba (1.0, 0.0, 0.0, 0.0);
            context.set_operator (Cairo.Operator.SOURCE);
            context.paint ();
        
            return true;
        }
            
    
        private void draw_mask(Cairo.Context context, double x, double y, double width, double height, double clip_amount) {
            // This shape is what will be erased
            context.move_to (x, y);

            if (panel_position == Services.Settings.WingpanelSlimPanelPosition.FLUSH_LEFT)
                context.move_to (x, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.SLANTED)
                context.line_to (x + clip_amount, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.SQUARED)
                context.line_to (x, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_1)
                context.curve_to (x + clip_amount, y, x, y + height-1, x + clip_amount, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_2)
                context.curve_to (x, y, x + clip_amount, y, x + clip_amount, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_3)
                context.curve_to (x, y + height - (clip_amount / 2) , x + (clip_amount / 2), y + height, x + clip_amount, y + height-1);
            
            context.line_to (x + width - clip_amount, y + height-1);
            
            if (panel_position == Services.Settings.WingpanelSlimPanelPosition.FLUSH_RIGHT)
                context.line_to (x + width, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.SLANTED)
                context.line_to (x + width, y);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.SQUARED)
                context.line_to (x + width, y + height-1);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_1)
                context.curve_to (x + width, y + height-1, x + width - clip_amount, y, x + width, y);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_2)
                context.curve_to (x + width - clip_amount, y + height-1, x + width - clip_amount, y, x + width, y);
            else if (panel_edge == Services.Settings.WingpanelSlimPanelEdge.CURVED_3)
                context.curve_to (x + width - (clip_amount / 2), y + height-1, x + width, y + height-1 - (clip_amount / 2), x + width, y);
                
            context.line_to (x + width, y + height);
            context.line_to (x, y + height);
            context.line_to (x, y);
        }
        
        
        private void on_settings_update () {
            this.panel_position = settings.panel_position;
            this.panel_edge = settings.panel_edge;
            this.auto_hide = settings.auto_hide;
            
            if (auto_hide)
                queue_move_out ();
            else
                first_run = true;
            queue_draw ();
        }
    }
}
