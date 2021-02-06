/*-
 * Copyright (c) 2013-2018 elementary LLC. (https://elementary.io)
 * Copyright (C) 2013 Tom Beckmann <tomjonabc@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Code.Plugins {
    public class OutlinePlugin : Peas.ExtensionBase, Peas.Activatable {
        public Object object { owned get; construct; }

        Scratch.Services.Interface scratch_interface;
        SymbolOutline? current_view = null;
        unowned Scratch.MainWindow window;

        OutlinePane? container = null;

        Gee.LinkedList<SymbolOutline> views;

        private Gtk.Grid placeholder;

        construct {
            var placeholder_label = new Gtk.Label (_("No Symbols Found"));
            placeholder_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            placeholder = new Gtk.Grid ();
            placeholder.halign = placeholder.valign = Gtk.Align.CENTER;
            placeholder.row_spacing = 3;
            placeholder.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            placeholder.attach (new Gtk.Image.from_icon_name ("plugin-outline-symbolic", Gtk.IconSize.DND), 0, 0);
            placeholder.attach (placeholder_label, 0, 1);

            views = new Gee.LinkedList<SymbolOutline> ();
            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/io/elementary/code/plugin/outline");
        }

        public void activate () {
            scratch_interface = (Scratch.Services.Interface)object;
            scratch_interface.hook_document.connect (on_hook_document);
            scratch_interface.hook_window.connect (on_hook_window);
        }

        public void deactivate () {
            container.destroy ();
        }

        public void update_state () {

        }

        void on_hook_window (Scratch.MainWindow window) {
            if (container != null)
                return;

            this.window = window;

            container = new OutlinePane ();
            container.add (placeholder);
        }

        void on_hook_document (Scratch.Services.Document doc) {
            if (current_view != null &&
                current_view.doc == doc &&
                current_view.get_source_list ().get_parent () != null) {

                /* Ensure correct source list shown */
                container.set_visible_child (current_view.get_source_list ());

                return;
            }

            SymbolOutline view = null;
            foreach (var v in views) {
                if (v.doc == doc) {
                    view = v;
                    break;
                }
            }

            if (view == null && doc.file != null) {
                var mime_type = doc.mime_type;
                switch (mime_type) {
                    case "text/x-vala":
                        view = new ValaSymbolOutline (doc);
                        break;
                    case "text/x-csrc":
                    case "text/x-chdr":
                    case "text/x-c++src":
                    case "text/x-c++hdr":
                        view = new CtagsSymbolOutline (doc);
                        break;
                }

                if (view != null) {
                    view.closed.connect (() => {remove_view (view);});
                    view.goto.connect (goto);
                    views.add (view);
                    view.parse_symbols ();
                }
            }

            if (view != null) {
                var source_list = view.get_source_list ();
                if (source_list.parent == null)
                    container.add (source_list);
                container.set_visible_child (source_list);
                container.show_all ();
                current_view = view;
                add_container ();
            } else {
                container.set_visible_child (placeholder);
            }
        }

        void add_container () {
            if (container.get_parent () == null) {
                window.sidebar.add_tab (container);
                container.show_all ();
            }
        }

        void remove_container () {
            var parent = container.get_parent ();
            if (parent != null) {
                parent.remove (container);
            }
        }

        void remove_view (SymbolOutline view) {
            views.remove (view);
            var source_list = view.get_source_list ();
            if (source_list.parent == container)
                container.remove (source_list);
            if (views.is_empty)
                remove_container ();
            view.goto.disconnect (goto);
        }

        void goto (Scratch.Services.Document doc, int line) {
            scratch_interface.open_file (doc.file);

            var text = doc.source_view;
            Gtk.TextIter iter;
            text.buffer.get_iter_at_line (out iter, line - 1);
            text.buffer.place_cursor (iter);
            text.scroll_to_iter (iter, 0.0, true, 0.5, 0.5);
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Code.Plugins.OutlinePlugin));
}
