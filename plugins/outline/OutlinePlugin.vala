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

            weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
            default_theme.add_resource_path ("/io/elementary/code/plugin/outline");
        }

        public void activate () {
            scratch_interface = (Scratch.Services.Interface)object;
            scratch_interface.hook_document.connect (on_hook_document);
            scratch_interface.hook_window.connect (on_hook_window);
        }

        public void deactivate () {
            scratch_interface.hook_document.disconnect (on_hook_document);
            scratch_interface.hook_window.disconnect (on_hook_window);
            scratch_interface.manager.window.document_view.docs.foreach (remove_outline_from_doc);
        }

        public void update_state () {
        }

        public void on_hook_window (Scratch.MainWindow window) {
            if (window != null) {
                on_hook_document (window.get_current_document ());
            }
        }

        void on_hook_document (Scratch.Services.Document? doc) {
            if (doc != null && doc.file != null && !doc.has_outline_widget ()) {
                SymbolOutline outline = null;
                var mime_type = doc.mime_type;
                switch (mime_type) {
                    case "text/x-vala":
                        outline = new ValaSymbolOutline (doc);
                        break;
                    case "text/x-csrc":
                    case "text/x-chdr":
                    case "text/x-c++src":
                    case "text/x-c++hdr":
                        outline = new CtagsSymbolOutline (doc);
                        break;
                }
                if (outline != null) {
                    add_outline_to_doc (doc, outline);
                }
            }
        }

        private void add_outline_to_doc (Scratch.Services.Document doc, SymbolOutline outline) {
            outline.goto.connect ((doc, line) => {
                scratch_interface.open_file (doc.file);

                var text = doc.source_view;
                Gtk.TextIter iter;
                text.buffer.get_iter_at_line (out iter, line - 1);
                text.buffer.place_cursor (iter);
                text.scroll_to_iter (iter, 0.0, true, 0.5, 0.5);
            });
            outline.parse_symbols ();
            doc.add_outline_widget (outline.get_source_list ());
            doc.set_data<SymbolOutline> ("SymbolOutline", outline);
        }

        private void remove_outline_from_doc (Scratch.Services.Document doc) {
            doc.remove_outline_widget ();
            doc.steal_data<SymbolOutline> ("SymbolOutline");
        }
    }
}

[ModuleInit]
public void peas_register_types (GLib.TypeModule module) {
    var objmodule = module as Peas.ObjectModule;
    objmodule.register_extension_type (typeof (Peas.Activatable), typeof (Code.Plugins.OutlinePlugin));
}
