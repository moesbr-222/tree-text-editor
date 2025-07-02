import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(TreeTextEditorApp());
}

class TreeTextEditorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TreeTextEditor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: TreeTextEditorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TreeTextEditorScreen extends StatefulWidget {
  @override
  _TreeTextEditorScreenState createState() => _TreeTextEditorScreenState();
}

class _TreeTextEditorScreenState extends State<TreeTextEditorScreen> {
  TextEditingController _textController = TextEditingController();
  List<FileSystemEntity> _files = [];
  File? _currentFile;
  String _currentContent = '';
  String _rootPath = '';
  bool _hasChanges = false;
  
  final List<String> _supportedExtensions = [
    '.txt', '.py', '.js', '.html', '.md', '.css', '.json', '.xml', '.yaml', '.yml', '.dart', '.java', '.cpp', '.c'
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadFiles();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _loadFiles() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (directory != null) {
        _rootPath = directory.path;
        _scanDirectory(directory);
      }
    } catch (e) {
      print('Error loading files: $e');
      _showSnackBar('خطا در بارگذاری فایل‌ها: ${e.toString()}');
    }
  }

  void _scanDirectory(Directory directory) {
    try {
      final entities = directory.listSync();
      setState(() {
        _files = entities.where((entity) {
          if (entity is File) {
            final extension = _getFileExtension(entity.path);
            return _supportedExtensions.contains(extension.toLowerCase());
          }
          return entity is Directory && !entity.path.contains('/.');
        }).toList();
        
        _files.sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      });
    } catch (e) {
      print('Error scanning directory: $e');
      _showSnackBar('خطا در اسکن پوشه: ${e.toString()}');
    }
  }

  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    return lastDot != -1 ? path.substring(lastDot) : '';
  }

  Color _getFileColor(String extension) {
    switch (extension.toLowerCase()) {
      case '.py':
        return Colors.green;
      case '.js':
        return Colors.yellow[700]!;
      case '.html':
        return Colors.orange;
      case '.css':
        return Colors.blue;
      case '.json':
        return Colors.purple;
      case '.xml':
        return Colors.red;
      case '.md':
        return Colors.grey;
      case '.dart':
        return Colors.blue[800]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Future<void> _openFile(File file) async {
    if (_hasChanges) {
      final shouldDiscard = await _showDiscardDialog();
      if (!shouldDiscard) return;
    }

    try {
      final content = await file.readAsString();
      setState(() {
        _currentFile = file;
        _currentContent = content;
        _textController.text = content;
        _hasChanges = false;
      });
    } catch (e) {
      _showSnackBar('خطا در باز کردن فایل: ${e.toString()}');
    }
  }

  Future<void> _saveFile() async {
    if (_currentFile != null) {
      try {
        await _currentFile!.writeAsString(_textController.text);
        setState(() {
          _currentContent = _textController.text;
          _hasChanges = false;
        });
        _showSnackBar('فایل با موفقیت ذخیره شد');
      } catch (e) {
        _showSnackBar('خطا در ذخیره فایل: ${e.toString()}');
      }
    }
  }

  Future<void> _createNewFile() async {
    final fileName = await _showInputDialog('نام فایل جدید را وارد کنید:', 'example.txt');
    if (fileName != null && fileName.isNotEmpty) {
      try {
        final file = File('$_rootPath/$fileName');
        await file.create();
        _loadFiles();
        _showSnackBar('فایل جدید ایجاد شد');
      } catch (e) {
        _showSnackBar('خطا در ایجاد فایل: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteFile(File file) async {
    final shouldDelete = await _showConfirmDialog('حذف فایل', 'آیا مطمئن هستید که می‌خواهید این فایل را حذف کنید؟');
    if (shouldDelete) {
      try {
        await file.delete();
        if (_currentFile?.path == file.path) {
          setState(() {
            _currentFile = null;
            _textController.clear();
            _currentContent = '';
            _hasChanges = false;
          });
        }
        _loadFiles();
        _showSnackBar('فایل حذف شد');
      } catch (e) {
        _showSnackBar('خطا در حذف فایل: ${e.toString()}');
      }
    }
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('تایید'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('خیر'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('بله'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showDiscardDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغییرات ذخیره نشده'),
        content: Text('تغییرات شما ذخیره نشده است. آیا می‌خواهید آن‌ها را نادیده بگیرید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('لغو'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('نادیده بگیر'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildFileTree() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.35,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            width: double.infinity,
            child: Row(
              children: [
                Icon(Icons.folder_open, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('فایل‌ها', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: _files.isEmpty 
              ? Center(child: Text('فایلی یافت نشد', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final entity = _files[index];
                    final isDirectory = entity is Directory;
                    final name = entity.path.split('/').last;
                    final extension = isDirectory ? '' : _getFileExtension(name);
                    
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        isDirectory ? Icons.folder : Icons.description,
                        color: isDirectory ? Colors.amber[700] : _getFileColor(extension),
                        size: 20,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: _currentFile?.path == entity.path,
                      selectedTileColor: Colors.blue[50],
                      onTap: () {
                        if (isDirectory) {
                          _scanDirectory(entity as Directory);
                        } else {
                          _openFile(entity as File);
                        }
                      },
                      onLongPress: !isDirectory ? () => _deleteFile(entity as File) : null,
                    );
                  },
                ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createNewFile,
                    icon: Icon(Icons.add, size: 16),
                    label: Text('فایل جدید', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loadFiles,
                  child: Icon(Icons.refresh, size: 16),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    color: _currentFile != null ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentFile?.path.split('/').last ?? 'فایلی انتخاب نشده',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentFile != null ? Colors.black87 : Colors.grey[600],
                      ),
                    ),
                  ),
                  if (_hasChanges)
                    Container(
                      margin: EdgeInsets.only(right: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('تغییر یافته', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  IconButton(
                    icon: Icon(Icons.save),
                    onPressed: _currentFile != null && _hasChanges ? _saveFile : null,
                    tooltip: 'ذخیره (Ctrl+S)',
                  ),
                ],
              ),
            ),
            Expanded(
              child: _currentFile != null
                  ? Container(
                      padding: EdgeInsets.all(16),
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          hintText: 'محتوای فایل را وارد کنید...',
                          contentPadding: EdgeInsets.all(12),
                        ),
                        textAlignVertical: TextAlignVertical.top,
                        onChanged: (value) {
                          setState(() {
                            _hasChanges = value != _currentContent;
                          });
                        },
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description, size: 64, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'فایلی انتخاب نشده',
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'از منوی سمت چپ فایلی را انتخاب کنید',
                            style: TextStyle(color: Colors.grey[500]),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.edit, size: 20),
            SizedBox(width: 8),
            Text('TreeTextEditor'),
          ],
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          if (_currentFile != null && _hasChanges)
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveFile,
              tooltip: 'ذخیره',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'بروزرسانی',
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                _buildFileTree(),
                _buildEditor(),
              ],
            );
          } else {
            return Column(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: _buildFileTree(),
                ),
                _buildEditor(),
              ],
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
