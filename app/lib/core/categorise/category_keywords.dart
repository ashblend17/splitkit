/// Words that suggest a category, by category key (the built-in categories, migration 0009).
/// Groceries and dining are `food`, utilities are `bills` (ISS-001's lists, plus the merchants
/// Indian bank SMS name). Lowercase; a two-word keyword matches two words in a row. In code, so
/// changing them takes a release; what you chose before comes first anyway (category_guesser).
const categoryKeywords = <String, List<String>>{
  'food': [
    // groceries
    'groceries', 'grocery', 'instamart', 'blinkit', 'zepto', 'bigbasket', 'dmart', 'mart', 'supermarket',
    'vegetables', 'fruits', 'milk', 'dairy', 'kirana', 'bakery', 'jiomart', 'freshtohome', 'licious',
    // dining
    'zomato', 'swiggy', 'restaurant', 'cafe', 'coffee', 'pub', 'bar', 'pizza', 'burger', 'starbucks', 'dominos',
    'kfc', 'mcdonalds', 'subway', 'dining', 'dinner', 'lunch', 'breakfast', 'food', 'snacks', 'tea', 'chai',
    'juice', 'biryani', 'dhaba', 'eatery', 'bistro', 'canteen', 'chaayos', 'haldirams', 'eatsure',
  ],
  'transport': [
    'uber', 'ola', 'rapido', 'metro', 'cab', 'taxi', 'auto', 'rickshaw', 'ride', 'fuel', 'petrol', 'diesel',
    'parking', 'toll', 'fastag', 'bus', 'train', 'irctc', 'redbus', 'hpcl', 'bpcl', 'iocl', 'indianoil',
    'blusmart', 'namma yatri', 'commute',
  ],
  'shopping': [
    'amazon', 'flipkart', 'myntra', 'ajio', 'nykaa', 'meesho', 'decathlon', 'croma', 'reliance digital',
    'shopping', 'clothes', 'shoes', 'mall', 'ikea', 'lenskart', 'tatacliq', 'shoppers stop', 'westside',
    'zara', 'uniqlo', 'pantaloons', 'apple store',
  ],
  'entertainment': [
    'netflix', 'spotify', 'hotstar', 'prime', 'movie', 'movies', 'cinema', 'pvr', 'inox', 'bookmyshow',
    'concert', 'ticket', 'tickets', 'gaming', 'steam', 'playstation', 'youtube', 'jiocinema', 'sonyliv',
    'bowling', 'district',
  ],
  'bills': [
    'electricity', 'water', 'wifi', 'internet', 'broadband', 'gas', 'recharge', 'mobile', 'postpaid',
    'prepaid', 'airtel', 'jio', 'vodafone', 'bsnl', 'bescom', 'tneb', 'mseb', 'tata power', 'adani',
    'dth', 'tatasky', 'tata play', 'bill', 'bills', 'insurance', 'lic', 'utility', 'utilities',
  ],
  'rent': ['rent', 'nobroker', 'landlord', 'maintenance', 'society'],
  'health': [
    'pharmacy', 'medicine', 'medicines', 'medical', 'hospital', 'clinic', 'doctor', 'apollo', '1mg',
    'pharmeasy', 'netmeds', 'dentist', 'diagnostics', 'chemist', 'gym', 'cultfit', 'cult', 'health',
  ],
  'travel': [
    'flight', 'flights', 'airline', 'airlines', 'indigo', 'vistara', 'akasa', 'makemytrip', 'goibibo',
    'cleartrip', 'ixigo', 'travel', 'holiday',
  ],
  'stay': ['hotel', 'hostel', 'airbnb', 'oyo', 'resort', 'homestay', 'stay'],
  'income': ['salary', 'payroll', 'stipend', 'dividend', 'bonus', 'interest'],
};
