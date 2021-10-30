# frozen_string_literal: true

class Templater
  def self.create_hunt!(name)
    send(name.parameterize.underscore)
  end

  def self.supported_hunts
    [
      'The Ultimate Christmas Light Scavenger Hunt Challenge',
      'Neighborhood Scavenger Hunt'
    ].sort
  end
end

private

def neighborhood_scavenger_hunt
  Hunt.create!(name: 'Neighborhood Scavenger Hunt',
               categories: [
                 Category.new(
                   name: 'Things in the Neighborhood',
                   points: 1,
                   items: [
                     'Basketball Hoop',
                     'A Truck',
                     'A Blue Car',
                     'For Sale Sign',
                     'Bricks',
                     'Someone Running',
                     'A Phone',
                     'A Brown House',
                     'Red Clothing',
                     'A FLying Bug',
                     'A Bicycle',
                     'Someone in Glasses',
                     'A Mailbox',
                     'A School',
                     'Construction',
                     'Recyclying Can',
                     'Headphones',
                     'Welcome Sign',
                     'A Ball',
                     'Someone Gardening',
                     'A Streetlamp',
                     'License Plate with K',
                     'Dog on a Walk',
                     'A Fence',
                     'A Friend',
                     'Blue Door',
                     'Kids Playing',
                     'A Family',
                     'A Stroller',
                     'A Yard Sign',
                     'A Hose',
                     'A Painted Rock',
                     'Toys'
                   ].map { |name| Item.new(name: name) }
                 )
               ])
end

def the_ultimate_christmas_light_scavenger_hunt_challenge
  Hunt.create!(name: 'The Ultimate Christmas Light Scavenger Hunt Challenge',
               categories: [
                 Category.new(
                   name: 'Lights',
                   points: 1,
                   items: ['Icicle Lights',
                           'Blinking Lights',
                           'All White Lights',
                           'Projection Lights',
                           'Color Lights',
                           'Laser Lights',
                           'Blue Lights',
                           'Tunnel of Lights'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Decor',
                   points: 2,
                   items: ['Star',
                           'Candy Cane',
                           'Wreath',
                           'Snowflake',
                           'Candle',
                           'Christmas Tree',
                           'Bell',
                           'Nativity Scene'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Characters',
                   points: 3,
                   items: ['Santa Claus',
                           'Snowman',
                           'Mrs. Claus',
                           'Elf',
                           'Rudolph',
                           'Carolers',
                           'The Grinch',
                           'Nativity Scene'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Phrases',
                   points: 4,
                   items: ['Merry Christmas',
                           'North Pole',
                           'Noel',
                           'Feliz Navidad',
                           'Peace',
                           'Ho Ho Ho!',
                           'Joy',
                           'Season\'s Greetings'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Special Features',
                   points: 5,
                   items: ['Lights timed to music',
                           'Laser light show',
                           'Decorations on a roof',
                           'Santa falling off the roof',
                           'Something dancing',
                           'Santa\'s sleigh with all the reindeer'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Challenges - Easy',
                   points: 6,
                   items: ['Take a kissing selfie in front of a light display',
                           'Stand on something tall and shout, "Merry Christmas to all and to all a good night!"',
                           'Hug a snowman',
                           'Take a photo of you as a shepherd in a nativity scene',
                           'Make a snow angel'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Challenges - Medium',
                   points: 8,
                   items: ['Find and eat a candy cane',
                           'Run around a tree 5x singing "Rocking Around the Christmas Tree"',
                           'Go up to a reindeer decoration and give him a pep talk',
                           'Dramatically say goodbye to Frosty the Snowman as though he has melted before you',
                           'Take a selfie with Santa'].map { |name| Item.new(name: name) }
                 ),
                 Category.new(
                   name: 'Challenges - Hard',
                   points: 10,
                   items: ['Go sing a Christmas carol to strangers',
                           'Find a stranger who can name each of "The 12 Days of Christmas"',
                           'Ask 3 strangers to tell you what they want for Christmas',
                           'Find a stranger that can name all of Santa\'s reindeer',
                           'Act out "Rudolph the Red Nosed Reindeer" while singing it'].map { |name| Item.new(name: name) }
                 )
               ])
end
