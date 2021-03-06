//
//  ARRCameraViewController.m
//  ARReading
//
//  Created by tclh123 on 13-3-4.
//  Copyright (c) 2013年 tclh123. All rights reserved.
//

#import "ARRCameraViewController.hpp"
#import "ARRGLView.hpp"
#import "GLMovieTexture.h"
#import "ARRMovie.h"

#import "QuartzHelpLibrary.h"

static float focalLength = 457.89;

@implementation ARRCameraViewController

// Param init
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    
	if (codeListRef == NULL)
		codeListRef = new CRCodeList();
	
	// OpenGL overlaid content view
	CGRect r = self.view.frame;
	r.size.height = r.size.width / 360.0 * 480.0;
	glView = [[ARRGLView alloc] initWithFrame:r];
    
	[glView setCameraFrameSize:CGSizeMake(480, 360)];
    [glView setupOpenGLViewWithFocalX:focalLength focalY:focalLength];
//	[glView startAnimation];  // startAnimation?    // 都不render看看
	[self.view addSubview:glView];
	[glView setCodeListRef:codeListRef];  // 使 GLView 能得到 识别出的 Code的矩阵

    [glView createTexture];
    
    // Movie Texture
    
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"sintel.ipad" ofType:@"mp4"];    
//    ARRMovie *movie = [[ARRMovie alloc] initWithPath:path frameRate:24];
//    glView.targetTextureId = movie.targetTextureId;
//    [movie start];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"sintel.ipad" ofType:@"mp4"];
    
    movie = [[GLMovieTexture alloc] initWithMovie:path context:glView.context];
	[movie setTextureId:glView.targetTextureId];    // movieTexture -> targetTextureId
	[movie setLoop:YES];
	[movie play];
    
//    [glView startAnimation];  // startAnimation?
}

// Main Loop
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
//    _DP("caputrue loop:")
//	_CRTic();
	
	[super captureOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
	
	int width = (int)bufferSize.width;      // bufferSize w:480 h:360 ?
	int height = (int)bufferSize.height;
	
	// do it
	if (chaincodeBuff == NULL)
		chaincodeBuff = (unsigned char*)malloc(sizeof(unsigned char) * width * height);
	
	int threshold = 100;
	
	// binarize for chain code
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			*(chaincodeBuff + x + y * width) = *(buffer + x + y * width) < threshold ? CRChainCodeFlagUnchecked : CRChainCodeFlagIgnore;
		}
	}
	
	float codeSize = 1;
	
//	int croppingSize = 64;
	
	CRChainCode *chaincode = new CRChainCode();
	
	chaincode->parsePixel(chaincodeBuff, width, height);
	
	CRCodeList::iterator it = codeListRef->begin();
	while(it != codeListRef->end()) {
		SAFE_DELETE(*it);
		++it;
	}
	codeListRef->clear();
	
	if (!chaincode->blobs->empty()) {
        
		std::list<CRChainCodeBlob*>::iterator blobIterator = chaincode->blobs->begin();
		while(blobIterator != chaincode->blobs->end()) {
			
			if (!(*blobIterator)->isValid(width, height)) {
				blobIterator++;
				continue;
			}
			
			CRCode *code = (*blobIterator)->code();
            
			if(code) {
                // INPUT: width, height, focalLength, focalLength, codeSize
				code->normalizeCornerForImageCoord(width, height, focalLength, focalLength);    // focalLength 焦距
				code->getSimpleHomography(codeSize);    // float codeSize = 1;
                //code->dumpMatrix();
				code->optimizeRTMatrinxWithLevenbergMarquardtMethod();  // 优化？？
				
//				// cropping code image area
//				code->crop(croppingSize, croppingSize, focalLength, focalLength, codeSize, buffer, width, height);
				
                // only when using OpenGL for rendering
                code->rotateOptimizedMatrixForOpenGL();
                
				codeListRef->push_back(code);
                
			}
			
			blobIterator++;
		}
	}
	
    dispatch_sync(dispatch_get_main_queue(), ^{
        [glView render];        // 这里 画 GL
    });
//	[glView render];        // 这里 画 GL
	
	SAFE_DELETE(chaincode);
//	_CRToc();   // 计时
}

@end
