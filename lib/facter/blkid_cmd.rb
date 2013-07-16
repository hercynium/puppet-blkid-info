
#
# Determine the path to the blkid command, attempting to install it
# if it's missing. If still missing, blkid_cmd will be empty. Otherwise,
# the blkid_cmd var will contain the path to the blkid command.
#


require "facter/util/resolution"


# see if the blkid command is available and if not, try to install
# the package that should contain it.
blkid_cmd_name = "blkid"
blkid_cmd = Facter::Util::Resolution.exec( "which " + blkid_cmd_name )
if ! blkid_cmd

    # if blkid isn't found, try to get it by using puppet to install
    # the required package...
    require "puppet"
    blkid_pkg_name = "e2fsprogs"
    Puppet.info( "Could not find #{blkid_cmd_name} command. Attempting to " +
                 "install pkg #{blkid_pkg_name} to get it." )
    # see here for more info:
    #  http://projects.puppetlabs.com/projects/puppet/wiki/Dsl_Hints_And_Tips_Patterns
    pkg_status =
        Puppet::Type.
            type(:package).
            newpackage(:name => blkid_pkg_name, :ensure => :installed).
            evaluate

    # see if it worked...
    if pkg_status.length != 0
        Puppet.info( "Package #{package_name} is not installed" )
    else
        Puppet.info( "Package #{package_name} is installed" )
    end

    # try to find it again
    blkid_cmd = Facter::Util::Resolution.exec( "which " + blkid_cmd_name )
end

# if its not present now, we will just get an empty value for this fact.
# fair enough.
Facter.add("blkid_cmd") {
    confine :kernel => "Linux" # only run on linux
    has_weight 500             # really, really early
    setcode { blkid_cmd }
}

# vi: set ts=4 sw=4 et :
