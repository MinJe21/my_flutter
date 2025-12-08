import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart';
import '../state/app_state.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  StateMachineController? _stateMachineController;
  SMIBool? _isChecking; 
  SMIBool? _isHandsUp;  
  SMINumber? _numLook;  
  SMITrigger? _trigSuccess; 
  SMITrigger? _trigFail;    

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _stateMachineController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_emailFocusNode.hasFocus) {
      _isChecking?.value = true; 
      _isHandsUp?.value = false;
    } else if (_passwordFocusNode.hasFocus) {
      _isChecking?.value = false;
      _isHandsUp?.value = true; 
    } else {
      _isChecking?.value = false;
      _isHandsUp?.value = false; 
    }
  }

  void _onRiveInit(Artboard artboard) {
    var controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    controller ??= StateMachineController.fromArtboard(artboard, 'Login Machine');
    
    if (controller != null) {
      artboard.addController(controller);
      _stateMachineController = controller;
      
      _isChecking = controller.findInput<bool>('isChecking') as SMIBool?;
      _isHandsUp = controller.findInput<bool>('isHandsUp') as SMIBool?;
      _numLook = controller.findInput<double>('numLook') as SMINumber?;
      _trigSuccess = controller.findInput<bool>('trigSuccess') as SMITrigger?;
      _trigFail = controller.findInput<bool>('trigFail') as SMITrigger?;
    }
  }

  void _signIn() {
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isChecking?.value = false;
      _isHandsUp?.value = false;
    });
    
    context.read<AppState>().signIn(
      _emailController.text.trim(),
      _passwordController.text.trim(),
      (errorMessage) {
        _trigFail?.fire(); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD6E2F0),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 250,
                width: 250,
                child: RiveAnimation.asset(
                  'assets/rive/login_animation.riv', 
                  onInit: _onRiveInit,
                  fit: BoxFit.contain,
                ),
              ),
              
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      focusNode: _emailFocusNode,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      onChanged: (value) {
                        if (_numLook != null) {
                           _numLook!.value = value.length.toDouble(); 
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      focusNode: _passwordFocusNode,
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _signIn,
                        child: const Text(
                          'Login', 
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
                child: const Text('Don\'t have an account? Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
