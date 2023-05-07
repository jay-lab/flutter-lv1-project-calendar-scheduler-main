import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_call/const/agora.dart';

class CamScreen extends StatefulWidget {
  const CamScreen({Key? key}) : super(key: key);

  @override
  State<CamScreen> createState() => _CamScreenState();
}

class _CamScreenState extends State<CamScreen> {
  RtcEngine? engine; //--영상통화 작업하기 (0:31) RtcEngine : 아고라 관련 작업을 하는 엔진

  // 내 ID
  int? uid = 0;

  // 상대 ID
  int? otherUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LIVE'),
      ),
      body: FutureBuilder<bool>( //-- 강의중 팁 : FutureBuilder는 자동완성기능에 존재하지 않기때문에 StreamBuilder를 자동완성으로 입력 후 수정하였음
        future: init(),
        builder: (context, snapshot) {
          print('--------stack');
          print(snapshot.stackTrace);
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
              ),
            );
          }

          if (!snapshot.hasData) { //-- error가 없는데 데이터가 없으면 아직 요청이 끝나지 않았다고 간주하여 snapshot.hasData로 로딩처리 구현
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack( //-- 영상통화 작업하기(20:40) > 위젯 위에 또다른 위젯을 올리기 위해 Stack 사용 > children에 명시한 '순서'대로 화면이 위에 올라간다.
                  /**
                   * 원래 이렇게되어있었다.
                   * Expanded(child:renderMainView(),),
                   * 그런데 위젯 위에 다른 위젯을 올리기 위해 Stack을 사용하면서 이처럼 수정되었다(20:40)
                   * **/
                  children: [
                    renderMainView(),
                    Align( //-- 이거안하면 renderMainView 위젯 위에 정 가운데에 출력되는데, Align을 사용하여 좌측 상단으로 정렬
                      alignment: Alignment.topLeft,
                      child: Container(
                        color: Colors.grey,
                        height: 160,
                        width: 120,
                        child: renderSubView(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton(
                  onPressed: () async { //-- 밑에서 await가 필요해 사용했으니 여기에 async 사용
                    if (engine != null) {
                      await engine!.leaveChannel();
                      engine = null;
                    }

                    Navigator.of(context).pop();
                  },
                  child: Text('채널 나가기'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  renderMainView() {
    if (uid == null) {
      return Center(
        child: Text('채널에 참여해주세요.'),
      );
    } else {
      // 채널에 참여하고 있을때
      return AgoraVideoView( //-- 영상통화 작업하기 (14:22)
        controller: VideoViewController( //-- 내꺼 보여줄때는 그냥 VideoViewController 상대방꺼 보여주기 위해서는 VideoViewController."remote"
          rtcEngine: engine!,
          canvas: VideoCanvas(
            uid: 0,
          ),
        ),
      );
    }
  }

  renderSubView() {
    if (otherUid == null) {
      return Center(
        child: Text('채널에 유저가 없습니다.'),
      );
    } else {
      return AgoraVideoView(
        controller: VideoViewController.remote( //-- 내꺼 보여줄때는 그냥 VideoViewController 상대방꺼 보여주기 위해서는 VideoViewController."remote"
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: otherUid),
          connection: RtcConnection(channelId: CHANNEL_NAME),
        ),
      );
    }
  }

  Future<bool> init() async {
    final resp = await [Permission.camera, Permission.microphone].request();

    final cameraPermission = resp[Permission.camera];
    final microphonePermission = resp[Permission.microphone];

    //-- granted : 권한이 존재
    //-- denied : 권한을 물어보기 전 상태
    //-- permanentlyDenied : 권한은 물어봤는데 거절 > 권한을 다시 물어볼 수가 없음.
    //-- restricted : (iOS에서만 존재하는 권한 상태) 아이들 폰에 대해 부모가 부분적으로 권한을 줄때
    //-- limited : (iOS에서만 존재하는 권한 상태) 사용자가 직접 몇가지 권한만 허가
    if (cameraPermission != PermissionStatus.granted ||
        microphonePermission != PermissionStatus.granted) {
      throw '카메라 또는 마이크 권한이 없습니다.';
    }

    if (engine == null) {
      engine = createAgoraRtcEngine(); //-- 아고라 api를 통해 엔진 가져오는 기능

      await engine!.initialize( //-- 엔진 초기화
        RtcEngineContext(
          appId: APP_ID,
        ),
      );

      engine!.registerEventHandler(
        RtcEngineEventHandler(
          // 내가 채널에 입장했을때
          // connection -> 연결정보
          // elapsed -> 연결된 시간 (연결된지 얼마나 됐는지)
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            print('채널에 입장했습니다. uid: ${connection.localUid}');
            setState(() {
              uid = connection.localUid;
            });
          },
          // 내가 채널에서 나갔을때
          onLeaveChannel: (RtcConnection connection, RtcStats stats) {
            print('채널 퇴장');
            setState(() {
              uid == null;
            });
          },
          // 상대방 유저가 들어왔을때
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            print('상대가 채널에 입장했습니다. otherUid: $remoteUid');
            setState(() {
              otherUid = remoteUid;
            });
          },
          // 상대가 나갔을때
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            print('상대가 채널에서 나갔습니다. otherUid: $remoteUid');

            setState(() {
              otherUid = null;
            });
          },
        ),
      );

      await engine!.enableVideo(); //-- 비디오(카메라) 활성화

      await engine!.startPreview(); //-- 카메라로 찍고있는 모습을 우리 핸드폰으로 송출하라는 명령어

      ChannelMediaOptions options = ChannelMediaOptions();

      await engine!.joinChannel( //-- 채널에 참석
        token: TEMP_TOKEN,
        channelId: CHANNEL_NAME,
        uid: 0, //-- 어차피 위 이벤트에서 uid 초기화 예정이기때문에 상관없다고
        options: options,
      );
    }

    return true;
  }
}
