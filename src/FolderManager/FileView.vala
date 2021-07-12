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
     * SourceList that displays folders and their contents.
     */
    public class FileView : Granite.Widgets.SourceList, Code.PaneSwitcher {
        private GLib.Settings settings;

        public signal void select (string file);
        public signal void close_all_docs_from_path (string path);

        // This is a workaround for SourceList silliness: you cannot remove an item
        // without it automatically selecting another one.
        public bool ignore_next_select { get; set; default = false; }
        public string icon_name { get; set; }
        public string title { get; set; }

        construct {
            width_request = 180;
            icon_name = "folder-symbolic";
            title = _("Folders");

            item_selected.connect (on_item_selected);

            settings = new GLib.Settings ("io.elementary.code.folder-manager");
        }

        private void on_item_selected (Granite.Widgets.SourceList.Item? item) {
            // This is a workaround for SourceList silliness: you cannot remove an item
            // without it automatically selecting another one.
            if (ignore_next_select) {
                ignore_next_select = false;
                return;
            }

            if (item is FileItem) {
                select (((FileItem) item).file.path);
            }
        }

        public void restore_saved_state () {
            foreach (unowned string path in settings.get_strv ("opened-folders")) {
                add_folder (new File (path), false);
            }
        }

        public ProjectFolderItem? open_folder (File folder) {
            if (is_open (folder)) {
                var existing = find_path (root, folder.path);
                if (existing is Granite.Widgets.SourceList.ExpandableItem) {
                    ((Granite.Widgets.SourceList.ExpandableItem)existing).expanded = true;
                    return (Scratch.FolderManager.ProjectFolderItem) existing;
                }

                return null;
            }

            return add_folder (folder, true);
        }

        public void collapse_all () {
            foreach (var child in root.children) {
                ((ProjectFolderItem) child).collapse_all ();
            }
        }

        public void order_folders () {
            var list = new Gee.ArrayList<ProjectFolderItem> ();

            foreach (var child in root.children) {
                root.remove (child as ProjectFolderItem);
                list.add (child as ProjectFolderItem);
            }

            list.sort ( (a, b) => {
                return a.name.down () > b.name.down () ? 0 : -1;
            });

            foreach (var item in list) {
                root.add (item);
            }
        }

        public void select_path (string path) {
            item_selected.disconnect (on_item_selected);
            selected = find_path (root, path);
            item_selected.connect (on_item_selected);
        }

        private unowned Granite.Widgets.SourceList.Item? find_path (Granite.Widgets.SourceList.ExpandableItem list,
                                                                    string path,
                                                                    bool expand = false) {
            foreach (var item in list.children) {
                if (item is Item) {
                    var code_item = (Item)item;
                    if (code_item.path == path) {
                        return (!)item;
                    }

                    if (item is Granite.Widgets.SourceList.ExpandableItem) {
                        var expander = item as Granite.Widgets.SourceList.ExpandableItem;
                        if (!path.has_prefix (code_item.path)) {
                            continue;
                        }

                        if (!expander.expanded) {
                             if (expand) {
                                 expander.expanded = true;
                             } else {
                                 continue;
                             }
                         }

                        unowned var recurse_item = find_path (expander, path, expand);
                        if (recurse_item != null) {
                            return recurse_item;
                        }
                    }
                }
            }

            return null;
        }

        public ProjectFolderItem? get_project_for_file (GLib.File file) {
            foreach (var item in root.children) {
                if (item is ProjectFolderItem) {
                    var folder = (ProjectFolderItem)item;
                    if (folder.is_git_repo && folder.contains_file (file)) {
                        return folder;
                    }
                }
            }

            return null;
        }

        public unowned Granite.Widgets.SourceList.Item? expand_to_path (string path) {
             return find_path (root, path, true);
        }

        /* Do global search on project containing the file path supplied in parameter */
        public void search_global (string path) {
            var item_for_path = (Item?)(expand_to_path (path));
            if (item_for_path != null) {
                var search_root = item_for_path.get_root_folder ();
                if (search_root is ProjectFolderItem) {
                    search_root.global_search (search_root.file.file);
                }
            }
        }

        public void clear_badges () {
            foreach (var child in root.children) {
                if (child is ProjectFolderItem) {
                    ((FolderItem)child).remove_all_badges ();
                }
            }
        }

        public void new_branch (string active_project_path) {
            unowned var active_project = (ProjectFolderItem)(find_path (root, active_project_path));
            if (active_project == null || !active_project.is_git_repo) {
                Gdk.beep ();
                return;
            }

            string? branch_name = null;
            var dialog = new Dialogs.NewBranchDialog (active_project);
            dialog.show_all ();
            if (dialog.run () == Gtk.ResponseType.APPLY) {
                branch_name = dialog.new_branch_name;
            }

            dialog.destroy ();
            if (branch_name != null) {
                active_project.new_branch (branch_name);
            }
        }

        private ProjectFolderItem? add_folder (File folder, bool expand) {
            if (is_open (folder)) {
                warning ("Folder '%s' is already open.", folder.path);
                return null;
            } else if (!folder.is_valid_directory (true)) { // Allow hidden top-level folders
                warning ("Cannot open invalid directory.");
                return null;
            }

            var folder_root = new ProjectFolderItem (folder, this); // Constructor adds project to GitManager
            this.root.add (folder_root);

            folder_root.expanded = expand;
            folder_root.closed.connect (() => {
                close_all_docs_from_path (folder_root.file.path);
                root.remove (folder_root);
                Scratch.Services.GitManager.get_instance ().remove_project (folder_root.file.file);
                write_settings ();
            });

            folder_root.close_all_except.connect (() => {
                foreach (var child in root.children) {
                    var project_folder_item = (ProjectFolderItem)child;
                    if (project_folder_item != folder_root) {
                        root.remove (project_folder_item);
                        Scratch.Services.GitManager.get_instance ().remove_project (project_folder_item.file.file);
                    }
                }

                write_settings ();
            });

            write_settings ();

            return folder_root;
        }

        private bool is_open (File folder) {
            foreach (var child in root.children)
                if (folder.path == ((Item) child).path)
                    return true;
            return false;
        }

        private void write_settings () {
            string[] to_save = {};

            foreach (var main_folder in root.children) {
                var saved = false;
                var folder_path = ((Item) main_folder).path;

                foreach (var saved_folder in to_save) {
                    if (folder_path == saved_folder) {
                        saved = true;
                        break;
                    }
                }

                if (!saved) {
                    to_save += folder_path;
                }
            }

            settings.set_strv ("opened-folders", to_save);
        }
    }
}
