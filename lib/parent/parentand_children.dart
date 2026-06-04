/*
  Bu sayfa, bir veli kullanıcısının çocuklarını hesabına bağlamasına olanak tanır.
  Veli, çocuğunun öğrenci ID'sini girerek onu sistemde arar ve bulursa çocuğunu hesabına bağlar.
*/
/*
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class CocukBaglamaSayfasi extends StatefulWidget {
  final Users veli;
  const CocukBaglamaSayfasi({super.key, required this.veli});

  @override
  State<CocukBaglamaSayfasi> createState() => _CocukBaglamaSayfasiState();
}

class _CocukBaglamaSayfasiState extends State<CocukBaglamaSayfasi> {
  final _idController = TextEditingController();
  bool isSearching = false;

  void _cocukBul() async {
    setState(() => isSearching = true);

    List<Users> users = await GoogleSheetService.getUsers();
    var student = users.firstWhere(
      (u) => u.app == _idController.text.trim(),
      orElse: () => Users(
        app: "",
        branches_id: "",
        first_name: "",
        last_name: "",
        email: "",
        phone: "",
        password_hash: "",
        role: "",
        profile_photo_url: "",
        amount: "",
        b_date: "",
        created_at: "",
        last_login: "",
        is_active: "",
      ),
    );

    if (student.app.isNotEmpty) {
      await GoogleSheetService.addParentStudent(widget.veli.app, student.app);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Çocuğunuz başarıyla bağlandı!")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Öğrenci bulunamadı. Lütfen ID'yi kontrol edin."),
        ),
      );
    }
    setState(() => isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Öğrenci Bağla")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Çocuğunuzun sistemdeki öğrenci ID'sini girerek onu hesabınıza bağlayabilirsiniz.",
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "Öğrenci ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSearching ? null : _cocukBul,
              child: const Text("Sistemi Sorgula ve Bağla"),
            ),
          ],
        ),
      ),
    );
  }
}
*/
import 'package:flutter/material.dart';
import 'package:EVOM_SPOR/datapage/data_page/data.dart';
import 'package:EVOM_SPOR/datapage/fetch_data_page.dart';

class CocukBaglamaSayfasi extends StatefulWidget {
  final Users veli;
  const CocukBaglamaSayfasi({super.key, required this.veli});

  @override
  State<CocukBaglamaSayfasi> createState() => _CocukBaglamaSayfasiState();
}

class _CocukBaglamaSayfasiState extends State<CocukBaglamaSayfasi> {
  final _idController = TextEditingController();
  late Future<Users?> _searchFuture;
  bool isSearching = false;

  void _cocukBul() {
    setState(() {
      isSearching = true;
      _searchFuture = _searchStudent();
    });
  }

  Future<Users?> _searchStudent() async {
    List<Users> users = await GoogleSheetService.getUsers();
    var student = users.firstWhere(
      (u) => u.app == _idController.text.trim(),
      orElse: () => Users(
        app: "",
        branches_id: "",
        first_name: "",
        last_name: "",
        email: "",
        phone: "",
        password_hash: "",
        role: "",
        profile_photo_url: "",
        amount: "",
        b_date: "",
        created_at: "",
        last_login: "",
        is_active: "",
      ),
    );

    if (student.app.isNotEmpty) {
      await GoogleSheetService.addParentStudent(widget.veli.app, student.app);
      return student;
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Öğrenci Bağla")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "Çocuğunuzun sistemdeki öğrenci ID'sini girerek onu hesabınıza bağlayabilirsiniz.",
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "Öğrenci ID",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isSearching ? null : _cocukBul,
              child: const Text("Sistemi Sorgula ve Bağla"),
            ),
            if (isSearching)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_searchFuture != null) {
      FutureBuilder<Users?>(
        future: _searchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            setState(() => isSearching = false);

            if (snapshot.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bir hata oluştu. Lütfen tekrar deneyin."),
                ),
              );
            } else if (snapshot.data != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Çocuğunuz başarıyla bağlandı!")),
              );
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    "Öğrenci bulunamadı. Lütfen ID'yi kontrol edin.",
                  ),
                ),
              );
            }
          }
          return const SizedBox.shrink();
        },
      );
    }
  }
}
