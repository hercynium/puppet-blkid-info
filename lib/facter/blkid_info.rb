
#
# Populate a set of facts containing info parsed from the output
# of the blkid command on Linux systems. The facts created will
# include the following:
#
#   blkid_cmd_failed => true if the blkid command failed, false otherwise
#                       if this var is true, the rest of the vars will not
#                       be set, except blkid_info_ok which will be false.
#
#   blkid_info_ok   => true if the output of blkid was sucessfully parsed,
#                      false if there was any error. If this var is false,
#                      the rest of the vars below will not be set.
#
#   blkid_dev_count => the number of devices for which blkid output info
#
#   blkid_dev_#{x}_tags => for device x, the tags parsed from the output 
#                          of the blkid command, as a colon-delimited string.
#                          if a tag contains any colons or a backslashes, they
#                          will be escaped with a backslash.
#
#   blkid_dev_#{x}_tag_#{y} => for device x, the value associated with tag y
#

def process_blkid_output( blkid_output_lines )

    # make sure whitespace is cleaned up...
    blkid_lines = blkid_output_lines.map { |l| l.strip }

    # collect the parsed info in this array
    blkid_info = blkid_lines.map { |line|

        # Split the path to the device node from the rest
        dev, rest = line.split( ": " )
        if ! dev
            raise Exception,
                  "problem parsing blkid output: could not get device" +
                  "from line #{line}"
        end

        # Scan the rest for KEY="value" pairs. Note: This may not be
        # reliable if, for example, a disk label contains an '"'. However,
        # speed wins for now.
        pairs = rest.scan( /([^"]+)="([^"]*)"(?: |$)/ )

        # if the match failed, move on to the next line.
        next if ! pairs or pairs.empty?

        bd_info = { "dev" => dev }

        # Add each pair to the blk dev info hash, lower-casing the key.
        pairs.each { |p|
            ( key, val ) = [ p[0].downcase(), p[1] ]
            # make sure the key is not nil, empty, or a duplicate,
            # and that the val isn't nil (empty string val is OK)
            if key.nil? or key.empty?
                raise Exception,
                      "problem parsing blkid output: for device " +
                      "#{dev}, could not get a key for value #{val}"
            elsif bd_info.has_key?( key )
                cval = bd_info[ key ]
                raise Exception,
                      "blkid info key conflict: output for device " +
                      "#{dev} has multiple instances of key '#{key}' " +
                      "with values '#{val}' and '#{cval}'"
            elsif val.nil?
                raise Exception,
                      "problem parsing blkid output: for device " +
                      "#{dev}, could not get a value for key #{key}"
            end
            bd_info[ key ] = val
        }

        # yeild the bd_info hash from the map block
        bd_info
    }

    return blkid_info
end

# generate the fact vars from the data in blkid_info
def gen_blkid_facts( blkid_info, base_weight )

    bwt = base_weight # shorter to type

    Facter.add( "blkid_dev_count" ) {
        has_weight bwt
        setcode {  blkid_info.count }
    }

    # iterate over the array by index, so we can use that in the names
    # of the fact vars we will produce.
    (1 .. blkid_info.count).each { |i|

        # get the hash for the current block dev
        bd = blkid_info[ i - 1 ]

        # each key/val pair for this block dev becomes a fact.
        bd.each { |k,v|
            Facter.add( "blkid_dev_#{i}_tag_#{k}" ) {
                has_weight bwt - i
                setcode { v }
            }
        }

        # put all the keys from this block dev info hash into a string,
        # delimited by ":". Escape any existing colons or backslashes
        # with a backslash. Add a fact with the resulting string.
        keys_str = bd.keys.sort.each{ |x| x.gsub( /([:\\])/, '\\1' )  }.join(":")
        Facter.add( "blkid_dev_#{i}_tags" ) {
            has_weight bwt - i
            setcode { keys_str }
        }
    }
end

def get_blkid_info

    # make sure blkid is available first
    blkid_cmd = Facter.value("blkid_cmd") or return

    begin

        # get the output from running the command as a string,
        # though there's some funkiness depending on the version
        # of facter we have...
        output = Facter::Util::Resolution.exec( blkid_cmd )

        # any error running the command will return nil and its
        # stderr should go to the console.
        if output.nil?
            Facter.add( "blkid_cmd_failed" ) { setcode { true } }
            return
        end

        # it appears that sometimes we get a string, and sometimes an array.
        blkid_lines = output.is_a?( Array ) ? output : output.split("\n")

        # parse/process the lines to create an array of hashes
        return process_blkid_output( blkid_lines )

    # catch any exceptions and report them
    rescue => details
        warn "Error processing output from blkid: #{details}"
    end
end

#
# Main function to kick off the whole thing.
#
def blkid_info_main
    # "base" weight of these facts. They need to be relatively
    # high-priority, but should't be too high. We will also
    # tweak some of the weights below so they print out in
    # a somewhat readable order when using facter.
    base_weight = 200

    begin
        if blkid_info = get_blkid_info()
            gen_blkid_facts( blkid_info, base_weight )
            return true
        end
    rescue => details
        Facter.add( "blkid_info_err" ) { setcode { details } }
    end
    return false
end

# call the main function and set the status based on what it returns.
# note: can't just call the function in the "setcode" block because
# something *really* funky is happening and it doesn't work.
status = blkid_info_main()
Facter.add( "blkid_info_ok" ) {
    setcode { status }
}

# vi: set ts=4 sw=4 et :
