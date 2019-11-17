// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/***
  BEGIN LICENSE

  Copyright (C) 2015 gero-bare <gero.bare[dot]gmail.com>
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

namespace Scratch.Plugins.SpellSettings {

    /**
     * Class for interacting with gsettings.
     */
    internal class Settings : Granite.Services.Settings {
        private const string SCHEMA = Constants.PROJECT_NAME + ".plugins.spell";

        public string language { get; set; }

        public Settings () {
            base (SCHEMA);
        }
    }
}
