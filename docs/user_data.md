# User data template override

The `compute.tf` utilizes the `tfe_user_data.sh.tpl` file found in the templates folder.
This code base provides `var.tfe_user_data_template` to present an alternative `*.tpl` file in either the root `./templates/` or the `./templates` local to your declaration. The variable accepts  just the filename `example.sh.tpl` to override the default `var.tfe_user_data_template` file and validates that the file is present and readable.

## output

There is a variable available `var.verbose_template` which, when set to true, enables the output `user_data_template`; this includes any *sensitive* data rendered in the template, so to expose the variable it must be called explicitly.

