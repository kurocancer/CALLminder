import 'package':flutter/material.dart';
import 'package':shared_preferences/shared_preferences.dart';
import 'package':image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'Male';
  DateTime? _selectedDOB;
  String? _profilePicPath;
  final _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      // Load from SharedPreferences first for speed
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _nameController.text = prefs.getString('profile_name') ?? user.displayName ?? '';
          _ageController.text = prefs.getString('profile_age') ?? '';
          _gender = prefs.getString('profile_gender') ?? 'Male';
          final dobStr = prefs.getString('profile_dob');
          if (dobStr != null) {
            final parts = dobStr.split('-');
            if (parts.length == 3) {
              _selectedDOB = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            }
          }
          _profilePicPath = prefs.getString('profile_pic');
        });
      }

      // Also load from Firestore (for cloud sync)
      final doc = await FirestoreService().getUserProfile(user.uid);
      if (doc != null && mounted) {
        setState(() {
          _nameController.text = doc['name'] ?? _nameController.text;
          _gender = doc['gender'] ?? _gender;
          _ageController.text = doc['age']?.toString() ?? _ageController.text;
          if (doc['dob'] != null) {
            _selectedDOB = (doc['dob'] as DateTime);
          }
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        setState(() => _profilePicPath = image.path);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_pic', image.path);
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _saveProfile() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name', _nameController.text);
      await prefs.setString('profile_age', _ageController.text);
      await prefs.setString('profile_gender', _gender);
      if (_selectedDOB != null) {
        await prefs.setString(
          'profile_dob',
          '${_selectedDOB!.year}-${_selectedDOB!.month.toString().padLeft(2, '0')}-${_selectedDOB!.day.toString().padLeft(2, '0')}',
        );
      }

      // Save to Firestore
      await FirestoreService().updateUserProfile(user.uid, {
        'name': _nameController.text,
        'gender': _gender,
        'age': int.tryParse(_ageController.text),
        'dob': _selectedDOB,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  Future<void> _selectDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDOB = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFF00D4FF).withOpacity(0.2),
                backgroundImage: _profilePicPath != null
                    ? FileImage(File(_profilePicPath!))
                    : null,
                child: _profilePicPath == null
                    ? Icon(Icons.camera_alt, size: 40, color: Color(0xFF00D4FF))
                    : null,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Tap to change profile picture',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 30),

            // Name field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Name',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Gender dropdown
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Gender',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _gender,
                isExpanded: true,
                dropdownColor: Color(0xFF1A1A1A),
                underline: SizedBox(),
                style: TextStyle(color: Colors.white),
                items: _genderOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null && mounted) {
                    setState(() => _gender = newValue);
                  }
                },
              ),
            ),
            SizedBox(height: 20),

            // Age field
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Age',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _ageController,
              style: TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            // Date of Birth
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Date of Birth',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: _selectDOB,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedDOB != null
                          ? '${_selectedDOB!.year}-${_selectedDOB!.month.toString().padLeft(2, '0')}-${_selectedDOB!.day.toString().padLeft(2, '0')}'
                          : 'Select Date of Birth',
                      style: TextStyle(color: _selectedDOB != null ? Colors.white : Colors.grey),
                    ),
                    Icon(Icons.calendar_today, color: Color(0xFF00D4FF)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 40),

            // Save button
            Center(
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00D4FF),
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Save Profile',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
