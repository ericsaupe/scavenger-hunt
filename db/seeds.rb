# frozen_string_literal: true

# Default Scavenger Hunt

Hunt.create!(name: 'The Ultimate Christmas Light Scavenger Hunt Challenge',
             code: 'TEST',
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
                         'Tunnel of Lights'].map { |name| Item.new(name:) }
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
                         'Nativity Scene'].map { |name| Item.new(name:) }
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
                         'Nativity Scene'].map { |name| Item.new(name:) }
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
                         'Season\'s Greetings'].map { |name| Item.new(name:) }
               ),
               Category.new(
                 name: 'Special Features',
                 points: 5,
                 items: ['Lights timed to music',
                         'Laser light show',
                         'Decorations on a roof',
                         'Santa falling off the roof',
                         'Something dancing',
                         'Santa\'s sleigh with all the reindeer'].map { |name| Item.new(name:) }
               ),
               Category.new(
                 name: 'Challenges - Easy',
                 points: 6,
                 items: ['Take a kissing selfie in front of a light display',
                         'Stand on something tall and shout, "Merry Christmas to all and to all a good night!"',
                         'Hug a snowman',
                         'Take a photo of you as a shepherd in a nativity scene',
                         'Make a snow angel'].map { |name| Item.new(name:) }
               ),
               Category.new(
                 name: 'Challenges - Medium',
                 points: 8,
                 items: ['Find and eat a candy cane',
                         'Run around a tree 5x singing "Rocking Around the Christmas Tree"',
                         'Go up to a reindeer decoration and give him a pep talk',
                         'Dramatically say goodbye to Frosty the Snowman as though he has melted before you',
                         'Take a selfie with Santa'].map { |name| Item.new(name:) }
               ),
               Category.new(
                 name: 'Challenges - Hard',
                 points: 10,
                 items: ['Go sing a Christmas carol to strangers',
                         'Find a stranger who can name each of "The 12 Days of Christmas"',
                         'Ask 3 strangers to tell you what they want for Christmas',
                         'Find a stranger that can name all of Santa\'s reindeer',
                         'Act out "Rudolph the Red Nosed Reindeer" while singing it'].map { |name| Item.new(name:) }
               )
             ])
