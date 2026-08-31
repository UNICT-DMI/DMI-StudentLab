import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

import '../social_models.dart';


// =============================================================================
// GROUP CHAT
// =============================================================================

class GroupChatLayer extends StatefulWidget {
  final int groupId;

  final String groupName;

  final String subjectName;

  final SocialUser currentUser;


  const GroupChatLayer({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.subjectName,
    required this.currentUser,
  });


  @override
  State<GroupChatLayer> createState() =>
      _GroupChatLayerState();
}


// =============================================================================
// STATE
// =============================================================================

class _GroupChatLayerState
    extends State<GroupChatLayer> {

  final TextEditingController _controller =
      TextEditingController();


  final ScrollController _scrollController =
      ScrollController();


  // ===========================================================================
  // MESSAGGI
  // ===========================================================================
  //
  // Per il momento rimangono locali.
  //
  // Non abbiamo ancora:
  //
  // GET /group_messages/{group_id}
  // POST /group_messages/{group_id}
  //
  // oppure WebSocket.
  //
  // ===========================================================================

  final List<_GroupChatMessage> _messages =
      [];


  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _controller.dispose();

    _scrollController.dispose();

    super.dispose();
  }


  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.darkElegance,

      appBar:
          AppBar(
        backgroundColor:
            AppColors.brandNightBlue,

        foregroundColor:
            AppColors.pureWhite,

        elevation:
            0,

        title:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Text(
              widget.groupName,

              maxLines:
                  1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                fontSize:
                    17,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            Text(
              widget.subjectName,

              maxLines:
                  1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  TextStyle(
                fontSize:
                    12,

                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.60,
                ),
              ),
            ),
          ],
        ),
      ),

      body:
          Column(
        children: [
          Expanded(
            child:
                _buildMessages(),
          ),

          _buildInput(),
        ],
      ),
    );
  }


  // ===========================================================================
  // MESSAGGI
  // ===========================================================================

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return _buildEmptyChat();
    }


    return ListView.builder(
      controller:
          _scrollController,

      padding:
          const EdgeInsets.all(
        16,
      ),

      itemCount:
          _messages.length,

      itemBuilder:
          (
        context,
        index,
      ) {

        final _GroupChatMessage message =
            _messages[index];


        return _buildMessage(
          message,
        );
      },
    );
  }


  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmptyChat() {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          28,
        ),

        child:
            Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width:
                  72,

              height:
                  72,

              decoration:
                  BoxDecoration(
                color:
                    AppColors.brandNightBlue,

                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),

              child:
                  const Icon(
                Icons.forum_outlined,

                color:
                    AppColors.skyBlue,

                size:
                    36,
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            const Text(
              'Nessun messaggio',

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    18,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              'Inizia la conversazione con gli altri partecipanti del gruppo.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors.pureWhite
                        .withOpacity(
                  0.50,
                ),

                fontSize:
                    12,

                height:
                    1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // MESSAGGIO
  // ===========================================================================

  Widget _buildMessage(
    _GroupChatMessage message,
  ) {
    final bool isMine =
        message.senderId ==
            widget.currentUser.id;


    if (isMine) {
      return Align(
        alignment:
            Alignment.centerRight,

        child:
            Container(
          constraints:
              const BoxConstraints(
            maxWidth:
                320,
          ),

          margin:
              const EdgeInsets.only(
            bottom:
                12,

            left:
                50,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                16,

            vertical:
                11,
          ),

          decoration:
              BoxDecoration(
            color:
                AppColors.socialBlue,

            borderRadius:
                const BorderRadius.only(
              topLeft:
                  Radius.circular(
                16,
              ),

              topRight:
                  Radius.circular(
                16,
              ),

              bottomLeft:
                  Radius.circular(
                16,
              ),

              bottomRight:
                  Radius.circular(
                5,
              ),
            ),
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              Text(
                message.text,

                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,

                  fontSize:
                      14,
                ),
              ),

              const SizedBox(
                height:
                    5,
              ),

              Text(
                _formatTime(
                  message.createdAt,
                ),

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.50,
                  ),

                  fontSize:
                      9,
                ),
              ),
            ],
          ),
        ),
      );
    }


    return Align(
      alignment:
          Alignment.centerLeft,

      child:
          Container(
        constraints:
            const BoxConstraints(
          maxWidth:
              320,
        ),

        margin:
            const EdgeInsets.only(
          bottom:
              12,

          right:
              50,
        ),

        padding:
            const EdgeInsets.all(
          12,
        ),

        decoration:
            BoxDecoration(
          color:
              AppColors.charcoalGrey,

          borderRadius:
              const BorderRadius.only(
            topLeft:
                Radius.circular(
              16,
            ),

            topRight:
                Radius.circular(
              16,
            ),

            bottomRight:
                Radius.circular(
              16,
            ),

            bottomLeft:
                Radius.circular(
              5,
            ),
          ),
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            GestureDetector(
              onTap:
                  () {
                _openUserCard(
                  message.senderId,
                );
              },

              child:
                  Text(
                message.senderName,

                style:
                    const TextStyle(
                  color:
                      AppColors.skyBlue,

                  fontSize:
                      13,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(
              height:
                  5,
            ),

            Text(
              message.text,

              style:
                  const TextStyle(
                color:
                    AppColors.pureWhite,

                fontSize:
                    14,
              ),
            ),

            const SizedBox(
              height:
                  5,
            ),

            Align(
              alignment:
                  Alignment.centerRight,

              child:
                  Text(
                _formatTime(
                  message.createdAt,
                ),

                style:
                    TextStyle(
                  color:
                      AppColors.pureWhite
                          .withOpacity(
                    0.35,
                  ),

                  fontSize:
                      9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // INPUT
  // ===========================================================================

  Widget _buildInput() {
    return SafeArea(
      top:
          false,

      child:
          Container(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          8,
          12,
          8,
        ),

        decoration:
            BoxDecoration(
          color:
              AppColors.brandNightBlue,

          border:
              Border(
            top:
                BorderSide(
              color:
                  AppColors.pureWhite
                      .withOpacity(
                0.08,
              ),
            ),
          ),
        ),

        child:
            Row(
          children: [
            Expanded(
              child:
                  TextField(
                controller:
                    _controller,

                minLines:
                    1,

                maxLines:
                    4,

                textInputAction:
                    TextInputAction.newline,

                style:
                    const TextStyle(
                  color:
                      AppColors.pureWhite,
                ),

                decoration:
                    InputDecoration(
                  hintText:
                      'Scrivi un messaggio...',

                  hintStyle:
                      TextStyle(
                    color:
                        AppColors.pureWhite
                            .withOpacity(
                      0.45,
                    ),
                  ),

                  filled:
                      true,

                  fillColor:
                      AppColors.charcoalGrey,

                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    borderSide:
                        BorderSide.none,
                  ),

                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        16,

                    vertical:
                        10,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),

            Container(
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.socialBlue,

                shape:
                    BoxShape.circle,
              ),

              child:
                  IconButton(
                tooltip:
                    'Invia',

                onPressed:
                    _sendMessage,

                icon:
                    const Icon(
                  Icons.send_rounded,

                  color:
                      AppColors.pureWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // INVIO
  // ===========================================================================

  void _sendMessage() {
    final String text =
        _controller.text
            .trim();


    if (text.isEmpty) {
      return;
    }


    final _GroupChatMessage message =
        _GroupChatMessage(
      senderId:
          widget.currentUser.id,

      senderName:
          widget.currentUser.name,

      text:
          text,

      createdAt:
          DateTime.now(),
    );


    setState(() {
      _messages.add(
        message,
      );
    });


    _controller.clear();


    _scrollToBottom();
  }


  // ===========================================================================
  // SCROLL
  // ===========================================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {

        if (!_scrollController
            .hasClients) {
          return;
        }


        _scrollController.animateTo(
          _scrollController
              .position
              .maxScrollExtent,

          duration:
              const Duration(
            milliseconds:
                250,
          ),

          curve:
              Curves.easeOut,
        );
      },
    );
  }


  // ===========================================================================
  // CARD UTENTE
  // ===========================================================================

  void _openUserCard(
    int userId,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          'Apertura profilo utente $userId',
        ),
      ),
    );


    /*
     * In seguito possiamo collegare:
     *
     * SocialUserProfilePage(
     *   userId: userId,
     * )
     */
  }


  // ===========================================================================
  // TIME
  // ===========================================================================

  String _formatTime(
    DateTime date,
  ) {
    final String hour =
        date.hour
            .toString()
            .padLeft(
              2,
              '0',
            );


    final String minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );


    return '$hour:$minute';
  }
}


// =============================================================================
// MESSAGGIO CHAT GRUPPO
// =============================================================================

class _GroupChatMessage {
  final int senderId;

  final String senderName;

  final String text;

  final DateTime createdAt;


  const _GroupChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });
}