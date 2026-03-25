class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final String? gender;
  final String? profilePhoto;
  final String role;
  final bool isActive;
  final bool isProfileComplete;
  final List<dynamic> savedAddresses;
  
  UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.gender,
    this.profilePhoto,
    required this.role,
    this.isActive = true,
    this.isProfileComplete = false,
    this.savedAddresses = const [],
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'],
      email: json['email'],
      gender: json['gender'],
      profilePhoto: json['profile_photo'],
      role: json['role'] ?? 'customer',
      isActive: json['is_active'] ?? true,
      isProfileComplete: json['is_profile_complete'] ?? false,
      savedAddresses: json['saved_addresses'] ?? [],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'email': email,
      'gender': gender,
      'profile_photo': profilePhoto,
      'role': role,
      'is_active': isActive,
      'is_profile_complete': isProfileComplete,
      'saved_addresses': savedAddresses,
    };
  }
  
  UserModel copyWith({
    String? name,
    String? email,
    String? gender,
    String? profilePhoto,
    bool? isProfileComplete,
  }) {
    return UserModel(
      id: id,
      phone: phone,
      name: name ?? this.name,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      role: role,
      isActive: isActive,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      savedAddresses: savedAddresses,
    );
  }
}
