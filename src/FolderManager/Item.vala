/*-
 * Copyright (c) 2017 elementary LLC. (https://elementary.io),
 *               2013 Julien Spautz <spautz.julien@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 3
 * as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Julien Spautz <spautz.julien@gmail.com>, Andrei-Costin Zisu <matzipan@gmail.com>
 */

namespace Scratch.FolderManager {
    /**
     * Common abstract class for file and folder items.
     */
    public abstract class Item: Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
        public File file { get; construct; }

        public FileView view { get; construct; }
        public string path {
            owned get { return file.path; }
            set { file.path = value; }
        }

        construct {
            selectable = true;
            editable = true;
            name = file.name;
            icon = file.icon;
            edited.connect (rename);
            tooltip = Scratch.Utils.replace_home_with_tilde (file.path);

            notify["activatable-tooltip"].connect (() => {
                tooltip = ("%s\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP).printf (
                    Scratch.Utils.replace_home_with_tilde (file.path),
                    activatable_tooltip
                );
            });
        }

        protected void rename (string new_name) {
            file.rename (new_name);
        }

        protected void trash () {
            file.trash ();
        }

        public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            if (a is RenameItem) {
                return -1;
            } else if (b is RenameItem) {
                return 1;
            }

            if (a is FolderItem && b is FileItem) {
                return -1;
            } else if (a is FileItem && b is FolderItem) {
                return 1;
            }

            return File.compare (((Item)a).file, ((Item)b).file);
        }

        public bool allow_dnd_sorting () {
            return false;
        }

        public void show_app_chooser (File file) {
            if (in_sandbox) {
                var portal = ((Scratch.Application) GLib.Application.get_default ()).portal;
                var parent = new Xdp.Gtk3.Parent (((Gtk.Application) GLib.Application.get_default ()).active_window);

                portal.open_uri.begin (parent, file.file.get_uri (), Xdp.OpenUriFlags.ASK, null, (obj, res) => {
                    try {
                        portal.open_uri.end (res);
                    } catch (Error e) {
                        warning (e.message);
                    }
                });
            } else {
                var dialog = new Gtk.AppChooserDialog (new Gtk.Window (), Gtk.DialogFlags.MODAL, file.file);
                dialog.deletable = false;

                if (dialog.run () == Gtk.ResponseType.OK) {
                    var app_info = dialog.get_app_info ();
                    if (app_info != null) {
                        launch_app_with_file (app_info, file.file);
                    }
                }

                dialog.destroy ();
            }
        }

        public void launch_app_with_file (AppInfo app_info, GLib.File file) {
            var file_list = new List<GLib.File> ();
            file_list.append (file);

            try {
                app_info.launch (file_list, null);
            } catch (Error e) {
                warning (e.message);
            }
        }

        public ProjectFolderItem? get_root_folder (Granite.Widgets.SourceList.ExpandableItem? start = null) {
            if (start == null) {
                start = this;
            }

            if (start is ProjectFolderItem) {
                return start as ProjectFolderItem;
            } else if (start.parent is ProjectFolderItem) {
                return start.parent as ProjectFolderItem;
            } else if (start.parent != null) {
                return get_root_folder (start.parent);
            } else {
                return null;
            }
        }
    }
}
