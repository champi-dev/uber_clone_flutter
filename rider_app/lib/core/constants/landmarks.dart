class Landmark {
  final String name;
  final double lat;
  final double lng;
  final String category;
  const Landmark(this.name, this.lat, this.lng, this.category);
}

const monteriaLandmarks = <Landmark>[
  Landmark('CC Alamedas del Sinú', 8.7489, -75.8814, 'Shopping'),
  Landmark('Universidad de Córdoba', 8.7837, -75.8608, 'University'),
  Landmark('Parque Lineal Río Sinú', 8.7520, -75.8835, 'Park'),
  Landmark('Hospital San Jerónimo', 8.7573, -75.8862, 'Hospital'),
  Landmark('Aeropuerto Los Garzones', 8.8236, -75.8258, 'Airport'),
  Landmark('CC Buenavista', 8.7364, -75.8783, 'Shopping'),
  Landmark('Plaza de la Cruz', 8.7530, -75.8820, 'Landmark'),
  Landmark('Terminal de Transportes', 8.7665, -75.8724, 'Transit'),
  Landmark('Estadio Jaraguay', 8.7589, -75.8775, 'Stadium'),
  Landmark('Barrio Mocarí', 8.7700, -75.8650, 'Residential'),
  Landmark('Barrio La Castellana', 8.7350, -75.8850, 'Residential'),
  Landmark('CC Nuestro Montería', 8.7480, -75.8780, 'Shopping'),
  Landmark('Colegio La Salle', 8.7550, -75.8790, 'School'),
  Landmark('Zona Industrial', 8.7900, -75.8550, 'Industrial'),
  Landmark('Country Club de Montería', 8.7300, -75.8900, 'Club'),
];

// Default rider simulated start location (city center).
const monteriaCenter = (lat: 8.7530, lng: -75.8820);
