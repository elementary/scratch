/*
 * Copyright (c) 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Marius Meisenzahl <mariusmeisenzahl@gmail.com>
 */

public class Scratch.Services.AppTemplate {
    private string _content;

    public AppTemplate (string content) {
        _content = content;
    }

    public string render (Gee.HashMap<string, string> context) {
        int index = 0;
        string s = "";
        do {
            int start_index = index;
            int found_start_index = _content.index_of ("{{", start_index);
            if (found_start_index == -1) {
                break;
            }

            int found_end_index = _content.index_of ("}}", found_start_index + 2);
            if (found_end_index == -1) {
                break;
            }

            var key = _content.substring (found_start_index + 2, found_end_index - found_start_index - 2).strip ();

            s += _content.substring (index, found_start_index - index);
            s += context[key];

            index = found_end_index + 2;
        } while (index < _content.length);

        if (index == 0) {
            return _content;
        }

        s += _content.substring (index);

        return s;
    }
}
