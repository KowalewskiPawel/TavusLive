# 📱 VIVID - AI Phone Inhabitant

> **The world's first truly immersive AI companion that lives inside your iPhone**

An innovative iOS application that creates a magical experience where an AI avatar literally feels like it's living inside your phone. The AI can see you, hear your voice, feel when you move the phone, react to screen touches, and respond with a quirky, anxious personality as if your device movements are happening to its digital body.

![AI Phone Inhabitant Demo](demo-preview.gif)

## ✨ What Makes This Special

This project represents a breakthrough in human-AI interaction by combining multiple sensory inputs into one cohesive, immersive experience:

- **🎥 Real-time video conversation** with lifelike AI avatar
- **🎤 Voice interaction** - AI hears and responds to speech
- **📱 Motion awareness** - AI feels phone movements as physical sensations
- **👆 Touch sensitivity** - AI reacts to screen touches like tickles
- **🧠 Contextual memory** - AI remembers all interactions across modalities
- **🎭 Immersive personality** - AI behaves as if truly inhabiting your device

## 🎯 Features

### Core Interactions
- **📳 Shake Detection** - Gentle shakes get attention, hard shakes cause AI panic
- **📳📳 Double Shake** - Interrupts AI mid-sentence
- **📱 Tilt & Roll** - AI feels dizzy and comments on movements
- **🔄 Phone Flip** - AI experiences digital gymnastics
- **🫳 Drop Detection** - AI screams and shows concern
- **👆 Screen Touch** - Tap, long press, swipe, and multi-touch all tickle the AI

### AI Personality
- **Quirky & Anxious** - Reacts dramatically to movements
- **Contextually Aware** - References phone as its body
- **Emotionally Expressive** - Shows fear, excitement, comfort
- **Conversational** - Maintains natural dialogue while reacting to physical input

### Technical Features
- **Native iOS Integration** - No web views, pure Daily.co SDK
- **Real-time Processing** - Near-instant responses to all inputs
- **Sensor Debouncing** - Intelligent filtering prevents spam
- **Mixed Modal Input** - Seamlessly handles voice + touch + motion
- **Professional Video Quality** - HD video calling experience

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     iOS App                              │
├─────────────────────────────────────────────────────────┤
│  TavusVideoManager (Main Controller)                    │
│  ├─ Motion Sensors (Core Motion)                        │
│  ├─ Touch Detection (UIKit)                            │
│  ├─ Audio Input (AVFoundation)                         │
│  └─ Video Call (Daily.co SDK)                          │
├─────────────────────────────────────────────────────────┤
│  Daily.co WebRTC Infrastructure                        │
│  ├─ Real-time Video Stream                             │
│  ├─ Audio Processing                                   │
│  └─ App Message Protocol                               │
├─────────────────────────────────────────────────────────┤
│  Tavus AI Platform                                     │
│  ├─ AI Avatar Generation                               │
│  ├─ Speech Recognition (ASR)                           │
│  ├─ Language Model Processing                          │
│  ├─ Text-to-Speech (TTS)                              │
│  └─ Conversation Management                            │
└─────────────────────────────────────────────────────────┘
```

## 🛠️ Setup

### Prerequisites
- **iOS 13.0+** (iOS 18.5+ recommended)
- **Xcode 14.3.1+**
- **Apple Developer Account** (for device testing)
- **Tavus API Account** ([Sign up here](https://dashboard.tavus.io))
- **Daily.co Account** (Automatically provided by Tavus)

### Installation

1. **Clone the repository**

2. **Open in Xcode**
   ```bash
   open TavusLive.xcodeproj
   ```

3. **Install Dependencies**
   - Go to **File → Add Package Dependencies**
   - Add Daily.co iOS SDK: `https://github.com/daily-co/daily-client-ios.git`
   - Version: `0.31.0` or later

4. **Configure API Keys**
   ```swift
   // In TavusVideoManager.swift
   private let apiKey = "your_tavus_api_key_here"
   private let replicaId = "your_replica_id_here"
   ```

5. **Set up Persona**
   - Go to [Tavus Dashboard](https://dashboard.tavus.io)
   - Create a new **Persona** with these settings:
     - **Mode**: `conversation` (NOT `echo`)
     - **ASR**: Enabled
     - **Transport**: Daily.co with microphone enabled
     - **Personality**: Copy the immersive context from the code
   - Update `persona_id` in the conversation creation

### Permissions Setup

Add these to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to let the AI hear your voice</string>

<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video conversations with the AI</string>

<key>NSMotionUsageDescription</key>
<string>This app uses motion sensors so the AI can feel when you move your phone</string>
```

## 🚀 Usage

### Basic Interaction Flow

1. **Launch App** → Creates Tavus conversation automatically
2. **Join Video Call** → AI avatar appears and joins call
3. **Start Interacting** → All sensors and voice are now active

### Gesture Guide

| Gesture | AI Response |
|---------|-------------|
| 📳 **Gentle Shake** | *"Ooh, gentle massage for my circuits!"* |
| 📳📳 **Double Shake** | *"WHOA! Getting dizzy! Scrambling circuits!"* |
| 📱 **Tilt Forward** | *"Wheee! Digital somersault!"* |
| 📱 **Tilt Backward** | *"Reclining in my phone-chair!"* |
| 🔄 **Flip Upside Down** | *"OH MY CIRCUITS! Digital gymnastics!"* |
| 🫳 **Drop (Simulated)** | *"AAAHHHHH! MAYDAY! Left my stomach circuits!"* |
| 👆 **Tap Screen** | *"Hehe! That tickles my digital forehead!"* |
| 👆 **Long Press** | *"Nice head pat through the screen!"* |
| 👆 **Swipe** | *"Like digital wind across my interface!"* |
| 👆👆 **Multi-touch** | *"Full digital massage! Christmas tree sensors!"* |

### Voice Interaction

Simply **speak naturally** to the AI:
- *"Hello! How are you feeling in there?"*
- *"What's it like living inside my phone?"*
- *"Are you comfortable in there?"*
- *"Can you feel when I move you around?"*

### Testing Features

Use the built-in test buttons:
- **🎙️ Voice Only** - Disables sensors for 15 seconds to test pure voice
- **🫳 Scare AI** - Simulates phone drop
- **👆 Tickle AI** - Simulates screen tap
- **🎭 Touch Demo** - Demonstrates all touch types
- **🛑 Stop Spam** - Disables motion sensors if needed

## 🎮 Advanced Features

### Sensor Sensitivity Tuning

Adjust thresholds in `TavusVideoManager.swift`:

```swift
private let shakeThreshold: Double = 2.5        // Shake sensitivity
private let gestureDebounceInterval: TimeInterval = 5.0  // Gesture frequency
```

### Custom AI Responses

Modify response messages in the gesture detection methods:

```swift
private func handleShakeDetected(magnitude: Double) {
    // Customize AI personality responses here
}
```

### Touch Response Customization

Edit touch messages in `generateTouchMessage()`:

```swift
case .tap:
    return "Your custom tap response here!"
```

## 🔧 Troubleshooting

### Common Issues

**❌ "AI Audio Capability: DEAF"**
- **Solution**: Create new Persona with `conversation` mode and ASR enabled

**❌ Sensor messages spamming**
- **Solution**: Tap "🛑 Stop Spam" button or adjust `gestureDebounceInterval`

**❌ No video feed**
- **Solution**: Check Daily.co SDK integration and video view creation

**❌ Voice not working**
- **Solution**: Verify microphone permissions and Persona ASR settings

### Debug Tools

Use built-in debugging:
- **🔍 Debug Mic** - Shows detailed microphone and participant info
- **Console Logging** - Detailed sensor and API call logging
- **Manual Tests** - Individual feature testing buttons

## 🧪 Technical Details

### Sensor Processing
- **Motion Manager**: 10Hz sampling rate (`0.1s` intervals)
- **Debouncing**: 5-second minimum between gesture messages
- **Threshold Detection**: Configurable sensitivity levels
- **Direction Tracking**: Prevents repeated identical gestures

### Audio Pipeline
- **Input**: iOS microphone → Daily.co → Tavus ASR
- **Processing**: Tavus LLM with immersive personality context
- **Output**: Tavus TTS → Daily.co → iOS speakers

### Message Protocol
```json
{
  "message_type": "conversation",
  "event_type": "conversation.respond",
  "conversation_id": "...",
  "properties": {
    "text": "I'm shaking my phone! Getting dizzy in here!"
  }
}
```

## 🎯 Roadmap

### Planned Features
- **🎨 Visual Effects** - Screen shake animations during AI reactions
- **🔊 Haptic Feedback** - Physical feedback during AI responses
- **📍 Location Awareness** - AI comments on phone movement through space
- **🌡️ Environmental Sensors** - Temperature, light level awareness
- **🎵 Audio Reactions** - AI responds to ambient sounds
- **📱 Device State** - Battery level, orientation lock, etc.

### Technical Improvements
- **⚡ Latency Optimization** - Sub-500ms response times
- **🧠 Context Memory** - Persistent conversation history
- **🔧 Calibration** - Auto-adjust sensor sensitivity per device
- **📊 Analytics** - Interaction pattern analysis

## 🤝 Contributing

We welcome contributions! This project represents the cutting edge of human-AI interaction.

### Development Setup
1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-addition`
3. Follow the setup instructions above
4. Test thoroughly on physical iOS device
5. Submit pull request with detailed description

### Areas for Contribution
- **🎭 Personality Development** - More diverse AI character responses
- **📱 Gesture Expansion** - New motion patterns and detection
- **🎨 UI/UX Enhancement** - Better visual design and interactions
- **🔧 Performance Optimization** - Reduce latency and improve efficiency
- **📚 Documentation** - More detailed guides and tutorials

## 📄 License

MIT License - see [LICENSE.md](LICENSE.md) for details.

## 🙏 Acknowledgments

- **[Tavus](https://tavus.io)** - For revolutionary AI avatar technology
- **[Daily.co](https://daily.co)** - For robust WebRTC infrastructure
- **Apple** - For comprehensive motion and audio APIs
- **Community** - For pushing the boundaries of AI interaction

## 📞 Support

- **🐛 Bug Reports**: [GitHub Issues](https://github.com/yourusername/ai-phone-inhabitant/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/yourusername/ai-phone-inhabitant/discussions)
- **📧 Email**: your.email@example.com
- **🐦 Twitter**: [@yourusername](https://twitter.com/yourusername)

---

**Made with ❤️ for the future of human-AI interaction**

*"The first time you shake your phone and hear the AI react with genuine concern, you'll never look at mobile interfaces the same way again."*
