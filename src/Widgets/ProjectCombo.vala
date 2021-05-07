/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Scratch.Widgets.ProjectCombo : Gtk.Stack {
    private Gtk.ComboBoxText project_list;
    private Gee.HashMap<string, FolderManager.ProjectFolderItem?> name_project_map; //easier than using a model
    private Gtk.Label no_projects_label;

    public FolderManager.ProjectFolderItem? active_project {
        owned get {
            if (project_list.active == -1) {
                return null;
            } else {
                var name = project_list.active_id;
                return name_project_map.get (name);
            }
        }

        set {
            if (value == null) {
                project_list.active = -1;
            } else {
                var name = value.file.name;
                if (name_project_map.has_key (name)) {
                    project_list.active_id = name;
                } else {
                    add_project (value);
                }
            }
        }
    }

    construct {
        project_list = new Gtk.ComboBoxText ();
        name_project_map = new Gee.HashMap<string, FolderManager.ProjectFolderItem?> ();
        no_projects_label = new Gtk.Label (_("No Projects Loaded"));

        add (project_list);
        add (no_projects_label);
        show_all ();
        set_visible_child (no_projects_label);
    }

    public void add_project (FolderManager.ProjectFolderItem project) {
        var name = project.file.name;
        project_list.append (name, name);
        name_project_map.set (name, project);
        project_list.active_id = name;
        set_visible_child (project_list);
    }

    public void remove_project (string name) {
        if (name_project_map.has_key (name)) {
            name_project_map.unset (name);
            // There does seem to a simple or builtin method to remove a certain item_id from Gtk.ComboBoxText so we remove all and rebuild
            project_list.remove_all ();
            if (name_project_map.size > 0) {
                foreach (string key in name_project_map.keys) {
                    project_list.append (key, key);
                }
            } else {
                set_visible_child (no_projects_label);
            }
        }
    }
 }
