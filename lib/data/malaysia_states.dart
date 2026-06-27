// Generated automatically using Overpass API script. Do not edit manually.

class CityArea {
  final String name;
  final double latitude;
  final double longitude;

  const CityArea({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class MalaysiaStateData {
  final String name;
  final List<CityArea> areas;

  const MalaysiaStateData({
    required this.name,
    required this.areas,
  });
}

const malaysiaStatesData = [
  MalaysiaStateData(
    name: 'Johor',
    areas: [
      CityArea(name: 'Ayer Hitam', latitude: 1.9181728, longitude: 103.1795162),
      CityArea(name: 'Batu Pahat', latitude: 1.8472584, longitude: 102.9346697),
      CityArea(name: 'Bukit Gambir', latitude: 2.2098953, longitude: 102.651091),
      CityArea(name: 'Johor Bahru', latitude: 1.4581986, longitude: 103.7649059),
      CityArea(name: 'Kluang', latitude: 2.0322421, longitude: 103.3190922),
      CityArea(name: 'Kukup', latitude: 1.3257891, longitude: 103.4442183),
      CityArea(name: 'Layang-Layang', latitude: 1.8147483, longitude: 103.4779698),
      CityArea(name: 'Muar', latitude: 2.0425046, longitude: 102.5658852),
      CityArea(name: 'Parit Sulong', latitude: 1.9759124, longitude: 102.8830335),
      CityArea(name: 'Renggam', latitude: 1.8847062, longitude: 103.401832),
      CityArea(name: 'Rengit', latitude: 1.6800091, longitude: 103.1457254),
      CityArea(name: 'Tangkak', latitude: 2.266995, longitude: 102.5399606),
    ],
  ),
  MalaysiaStateData(
    name: 'Kedah',
    areas: [
      CityArea(name: 'Alor Setar', latitude: 6.1231908, longitude: 100.3683962),
      CityArea(name: 'Bukit Kayu Hitam', latitude: 6.5053399, longitude: 100.4207711),
      CityArea(name: 'Sungai Petani', latitude: 5.6435195, longitude: 100.4869513),
    ],
  ),
  MalaysiaStateData(
    name: 'Kelantan',
    areas: [
      CityArea(name: 'Wakaf Bharu', latitude: 6.1217773, longitude: 102.2018315),
    ],
  ),
  MalaysiaStateData(
    name: 'Kuala Lumpur',
    areas: [
      CityArea(name: 'Batu Caves', latitude: 3.2369148, longitude: 101.6833464),
      CityArea(name: 'Kuala Lumpur', latitude: 3.1516964, longitude: 101.6942371),
    ],
  ),
  MalaysiaStateData(
    name: 'Melaka',
    areas: [
      CityArea(name: 'Alor Gajah', latitude: 2.3861261, longitude: 102.2149996),
      CityArea(name: 'Masjid Tanah', latitude: 2.3522253, longitude: 102.1089793),
      CityArea(name: 'Pulau Sebang', latitude: 2.4494099, longitude: 102.2326551),
    ],
  ),
  MalaysiaStateData(
    name: 'Negeri Sembilan',
    areas: [
      CityArea(name: 'Batu Kikir', latitude: 2.8289781, longitude: 102.3169465),
      CityArea(name: 'Gemas', latitude: 2.5812964, longitude: 102.6117487),
      CityArea(name: 'Gemencheh', latitude: 2.5301446, longitude: 102.4001362),
      CityArea(name: 'Linggi', latitude: 2.4854272, longitude: 102.010331),
    ],
  ),
  MalaysiaStateData(
    name: 'Pahang',
    areas: [
      CityArea(name: 'Bentong', latitude: 3.5196355, longitude: 101.9133469),
      CityArea(name: 'Kuantan', latitude: 3.7974493, longitude: 103.3219191),
      CityArea(name: 'Mentakab', latitude: 3.486451, longitude: 102.3514872),
      CityArea(name: 'Temerloh', latitude: 3.4505701, longitude: 102.4190974),
    ],
  ),
  MalaysiaStateData(
    name: 'Penang',
    areas: [
      CityArea(name: 'Butterworth', latitude: 5.4082015, longitude: 100.3697208),
      CityArea(name: 'George Town', latitude: 5.4141619, longitude: 100.3287352),
    ],
  ),
  MalaysiaStateData(
    name: 'Perak',
    areas: [
      CityArea(name: 'Ipoh', latitude: 4.5986817, longitude: 101.0900236),
      CityArea(name: 'Kampung Gajah', latitude: 4.1815449, longitude: 100.9372537),
      CityArea(name: 'Pulau Pangkor', latitude: 4.2265301, longitude: 100.5601498),
      CityArea(name: 'Taiping', latitude: 4.8546772, longitude: 100.7438831),
      CityArea(name: 'Teluk Intan', latitude: 4.023176, longitude: 101.026184),
    ],
  ),
  MalaysiaStateData(
    name: 'Perlis',
    areas: [
      CityArea(name: 'Arau', latitude: 6.4307281, longitude: 100.2718795),
    ],
  ),
  MalaysiaStateData(
    name: 'Sabah',
    areas: [
      CityArea(name: 'Kota Belud', latitude: 6.3497629, longitude: 116.4292891),
      CityArea(name: 'Kota Kinabalu', latitude: 5.9780066, longitude: 116.0728988),
      CityArea(name: 'Ranau', latitude: 5.9511437, longitude: 116.6662881),
      CityArea(name: 'Sandakan', latitude: 5.8391274, longitude: 118.1158598),
      CityArea(name: 'Tawau', latitude: 4.2435206, longitude: 117.885331),
    ],
  ),
  MalaysiaStateData(
    name: 'Sarawak',
    areas: [
      CityArea(name: 'Bintulu', latitude: 3.1874261, longitude: 113.0472803),
      CityArea(name: 'Kuching', latitude: 1.5597561, longitude: 110.345397),
      CityArea(name: 'Miri', latitude: 4.3940102, longitude: 113.9880199),
      CityArea(name: 'Sibu', latitude: 2.2906434, longitude: 111.8256158),
    ],
  ),
  MalaysiaStateData(
    name: 'Selangor',
    areas: [
      CityArea(name: 'Batang Kali', latitude: 3.4623963, longitude: 101.6550175),
      CityArea(name: 'Jenjarom', latitude: 2.8766037, longitude: 101.4988405),
      CityArea(name: 'Kajang', latitude: 2.9948437, longitude: 101.7896595),
      CityArea(name: 'Klang', latitude: 3.0448394, longitude: 101.4447363),
      CityArea(name: 'Petaling Jaya', latitude: 3.0988792, longitude: 101.6454202),
      CityArea(name: 'Rawang', latitude: 3.3197692, longitude: 101.5773144),
      CityArea(name: 'Shah Alam', latitude: 3.0739429, longitude: 101.5185278),
      CityArea(name: 'Subang Jaya', latitude: 3.051487, longitude: 101.5823339),
    ],
  ),
];

List<String> get malaysiaStates => malaysiaStatesData.map((e) => e.name).toList();
