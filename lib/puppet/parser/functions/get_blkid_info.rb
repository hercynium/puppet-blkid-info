
module Puppet::Parser::Functions
    newfunction(:get_blkid_info, :type => :rvalue, :doc => <<-END

This function returns an array of hashes containing the information gathered
by the blkid_info facter plugin.

*Description:*

    If the blkid_info facter plugin is working, this will collect the vars
    it set and produce a data-structure that is easier to work with for
    configuring the system.

*Required Arguments:*

    None.

*Optional Arguments:*

    None.

*Results:*

    Produces a data structure like this:

    [
      { dev   => '/dev/sdb1',
        label => "/disk1",
        type  => "ext3",
        uuid  => "f60e610f-7e73-4824-b366-592d9b803d50", ... },
      { dev   => '/dev/sdc1',
        label => "/disk2",
        type  => "ext3"
        uuid  => "951e142f-46fd-4258-a586-1ad19258c7d3", ... },
      ...
    ]

    Where each hash in the returned array contains the info output by blkid
    for a disk or partition. If nothing is output by blkid, the returned array
    will be empty.

*Errors:*

    An exception will be raised if:
      * The blkid_info facter plugin reported an error
      * The expected facter vars could not be collected or processed

*Examples:*

    $blkid_info = get_blkid_info()

END
    ) do |args|

        require 'pp'
        Puppet.debug("starting function get_blkid_info")
        # determine if the facter plugin ran and if it succeeded
        plugin_ok = get_facter_val( "blkid_info_ok" )
        if ! plugin_ok
            raise Puppet::ParseError,
                  "Can not get blkid info because the blkid_info facter " +
                  "plugin set blkid_info_ok to false"
        end

        # determine how many devices the plugin made vars for
        dev_count = get_facter_val( "blkid_dev_count" ).to_i()

        # 0 devices is OK
        return [] unless dev_count

        # for each device, get the info from the vars and build our data structure
        all_devs_inf = []
        for dev_num in 1 .. dev_count

            dev_tags_s = get_facter_val( "blkid_dev_#{dev_num}_tags" )

            dev_inf = {}

            # ruby 1.8 regexes don't have lookbehind, so we have to be "clever" :-/
            # if a tag has a : it will be escaped with a \, so let's figure that out...
            split_tags = dev_tags_s.split( /:/ )
            st_idx = 0
            while st_idx < split_tags.length
                # if the tag ends in an even number of backslashes, it's OK. that
                # includes 0. If its odd, we have to concat the next tag with a colon.
                # we shouldn't have any empty tags, but it's worth checking.
                tag = split_tags[st_idx]
                if ! split_tags[st_idx] =~ / (?: (?: [\\]{2} )+ | [^\\] ) $ | ^$ /x
                    tag += dev_tags_a[ st_idx + 1 ]
                    st_idx += 1
                end
                val = get_facter_val( "blkid_dev_#{dev_num}_tag_#{tag}" )
                dev_inf[ tag ] = val 
                st_idx += 1
            end

            all_devs_inf << dev_inf
        end

        Puppet.debug("finished function get_blkid_info")
        return all_devs_inf
    end
end

def get_facter_val( var_name )
    val = lookupvar("::#{var_name}")
    if val == :undefined
        raise Puppet::ParseError,
              "Can not get blkid info because the #{var_name}" +
              "variable is not defined"
    end
    return val
end

# vi: set ts=4 sw=4 et :
